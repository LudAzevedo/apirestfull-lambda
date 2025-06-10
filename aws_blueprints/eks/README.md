# Módulo Terraform AWS EKS (Elastic Kubernetes Service)

## Descrição

Este módulo Terraform provisiona um cluster Amazon EKS (Elastic Kubernetes Service) robusto e configurável na AWS. Ele foi projetado para ser modular e inclui o control plane do EKS, grupos de nós gerenciados personalizáveis, e integrações opcionais essenciais como o AWS Load Balancer Controller para gerenciamento avançado de tráfego, Nginx Ingress Controller para roteamento de entrada flexível, Fluent Bit para encaminhamento de logs de contêineres para o CloudWatch, e opções para gerenciamento de autenticação e autorização via ConfigMap `aws-auth`.

## Funcionalidades Principais

-   **Control Plane do EKS:** Criação do Control Plane do EKS com configurações de acesso ao endpoint (público e/ou privado) e logging integrado ao CloudWatch.
-   **IAM Roles Dedicadas:**
    -   Configuração de uma IAM Role específica para o cluster EKS (`eks_cluster_role`).
    -   Criação de uma IAM Role dedicada para os Node Groups (`eks_node_group_role`) com as políticas AWS gerenciadas necessárias (`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`).
-   **Grupos de Nós Gerenciados (Managed Node Groups):** Provisionamento flexível de grupos de nós com tipos de instância, tamanho (com auto-scaling), tipo de AMI, tamanho de disco, labels, taints e capacidade (On-Demand/Spot) configuráveis.
-   **AWS Load Balancer Controller (Opcional):** Instalação via Helm para permitir o provisionamento dinâmico de Application Load Balancers (ALBs) e Network Load Balancers (NLBs) a partir de Services e Ingresses do Kubernetes. Inclui a criação automática da IAM Role e Service Account necessárias utilizando IRSA (IAM Roles for Service Accounts).
-   **Nginx Ingress Controller (Opcional):** Instalação via Helm, configurado para ser exposto através de um Network Load Balancer (NLB) provisionado pelo AWS Load Balancer Controller (se este estiver habilitado).
-   **Fluent Bit (Logging de Containers - Opcional):** Implantação do Fluent Bit como um DaemonSet para coletar logs de todos os contêineres nos nós e encaminhá-los para o Amazon CloudWatch Logs. Inclui a criação da IAM Role e Service Account necessárias (IRSA).
-   **Gerenciamento de Acesso (Opcional):** Gerenciamento do ConfigMap `aws-auth` para mapear roles e usuários IAM adicionais ao sistema RBAC (Role-Based Access Control) do Kubernetes.

## Arquitetura de Alto Nível (com todos os componentes opcionais habilitados)

O diagrama abaixo ilustra os principais componentes e o fluxo de tráfego quando todas as funcionalidades opcionais estão habilitadas:

```
                                [Usuários/Tráfego da Internet]
                                            |
                                            v
                              [AWS Network Load Balancer (NLB)]  <-- Service do Nginx Ingress (gerenciado pelo AWS LBC)
                                            |
                                            v
                            [Pods do Nginx Ingress Controller] (em Node Groups, Namespace: var.nginx_ingress_namespace)
                                   (Réplicas: var.nginx_ingress_replica_count)
                                            | (Roteamento baseado em Recursos Ingress)
                                            v
      +-----------------------------------------------------------------------------------------+
      |                                 [Pods das Aplicações]                                   |
      |   (Expostos via Ingress ou Services tipo LoadBalancer em diferentes Node Groups/Pools)    |
      +-----------------------------------------------------------------------------------------+
          ^                                       |
          | (Tráfego interno ou via ALB/NLB)      v (Logs)
          |                                       |
[AWS Application/Network Load Balancer] <-------+ [Fluent Bit Pods (DaemonSet)] ---> [Amazon CloudWatch Logs]
  (Provisionado pelo AWS LBC para Services        (Coleta logs de todos os containers     (Grupo: var.fluent_bit_cloudwatch_log_group_name)
   tipo LoadBalancer de aplicações)                nos nós)

-------------------------------- Zona do Control Plane do EKS (Gerenciada pela AWS) ----------------------------------
  - Servidor API Kubernetes (Endpoint: output.cluster_endpoint)
  - etcd (Banco de dados do cluster)
  - Controller Manager, Scheduler
  - IAM Role do Cluster (output.cluster_iam_role_arn)
  - Logging do Control Plane (var.enabled_cluster_log_types) para CloudWatch
  - Provedor OIDC (output.cluster_oidc_issuer_url) para IRSA
--------------------------------------------------------------------------------------------------------------------

------------------------------------------ Zona dos Nós de Trabalho (Data Plane) ---------------------------------------
  Node Groups (configurados via var.node_groups):
  - Instâncias EC2 (Tipos: var.node_groups.*.instance_types, Capacidade: ON_DEMAND/SPOT)
  - IAM Role dos Nós (output.node_group_shared_iam_role_name)
  - Kubelet, Container Runtime (Docker, containerd), aws-node (Plugin CNI da AWS)
  - Security Groups (gerenciados pelo EKS e AWS LBC)
--------------------------------------------------------------------------------------------------------------------

-------------------------------------------------- Componentes Adicionais ----------------------------------------------
  - AWS Load Balancer Controller:
    - Pods no namespace kube-system
    - Service Account `aws-load-balancer-controller-sa` com IAM Role (IRSA) (output.aws_load_balancer_controller_sa_role_arn)
  - `aws-auth` ConfigMap (no namespace kube-system):
    - Mapeia IAM Roles/Users para o RBAC do Kubernetes (gerenciado se var.manage_aws_auth_configmap = true)
--------------------------------------------------------------------------------------------------------------------
```

## Como Começar (Getting Started)

### Pré-requisitos

Antes de usar este módulo, certifique-se de que você tem os seguintes pré-requisitos instalados e configurados:

1.  **Terraform:** Versão 1.0 ou superior ([Download Terraform](https://www.terraform.io/downloads.html)).
2.  **AWS CLI:** Versão 2.x ou superior, configurada com credenciais AWS que tenham permissão para criar os recursos EKS e relacionados (VPC, IAM, EC2, ELB, CloudWatch Logs, etc.). ([Configurar AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)).
3.  **kubectl:** Ferramenta de linha de comando para interagir com clusters Kubernetes ([Instalar kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)).
4.  **Provedor `gavinbunney/kubectl` para Terraform:** Este módulo utiliza o provedor `kubectl` para aplicar o manifesto do Fluent Bit. Ele será instalado automaticamente pelo `terraform init` devido à declaração no bloco `terraform { required_providers { ... } }` em `main.tf`.

### Configuração do Módulo

1.  **Crie um arquivo `.tf`** (ex: `meu-eks.tf`) no seu projeto Terraform.
2.  **Adicione o bloco do módulo** conforme o exemplo de uso abaixo, personalizando as variáveis conforme suas necessidades.
3.  **Inicialize o Terraform:**
    ```bash
    terraform init
    ```
4.  **Planeje e Aplique:**
    ```bash
    terraform plan  # Para visualizar as alterações que serão feitas
    terraform apply # Para provisionar os recursos (será solicitado confirmação)
    ```

### Configurando `kubectl`

Após a criação bem-sucedida do cluster, você precisará configurar o `kubectl` para interagir com ele. Use o AWS CLI:

```bash
aws eks update-kubeconfig --region SUA_REGIAO --name NOME_DO_SEU_CLUSTER
```

Substitua `SUA_REGIAO` pela região AWS onde o cluster foi criado (ex: `us-east-1`) e `NOME_DO_SEU_CLUSTER` pelo valor da variável `cluster_name` que você usou.

Você pode obter o nome do cluster e a região das saídas do módulo, se necessário:
`aws eks update-kubeconfig --region $(terraform output -raw region_name) --name $(terraform output -raw cluster_id)`
(Assumindo que você tenha `output "region_name" { value = data.aws_region.current.name }` e `output "cluster_id" { value = module.eks_cluster.cluster_id }` no seu arquivo Terraform raiz).

Verifique a conectividade:
```bash
kubectl get nodes
kubectl get all -A # Lista todos os recursos em todos os namespaces
```

## Variáveis de Entrada (Inputs)

As variáveis de entrada permitem personalizar extensivamente o cluster EKS e seus componentes. Consulte o arquivo `variables.tf` para a lista completa, descrições detalhadas, tipos e valores padrão.

### Configurações Gerais do Cluster EKS
*   `cluster_name`: (Obrigatório, string) Nome único para o cluster EKS.
*   `cluster_version`: (string, padrão: "1.29") Versão do Kubernetes para o cluster.
*   `tags`: (map(string), opcional) Tags AWS a serem aplicadas globalmente aos recursos criados pelo módulo.

### Rede e Load Balancing
*   `vpc_id`: (Obrigatório, string) ID da VPC onde o cluster será provisionado.
*   `subnet_ids`: (Obrigatório, list(string)) Lista de IDs de sub-redes para o control plane do EKS e, por padrão, para os node groups. Recomenda-se pelo menos 2 sub-redes em AZs diferentes para alta disponibilidade.
*   `endpoint_private_access`: (bool, padrão: `false`) Habilita o acesso privado ao endpoint do API server do Kubernetes de dentro da VPC.
*   `endpoint_public_access`: (bool, padrão: `true`) Habilita o acesso público ao endpoint do API server.
*   `public_access_cidrs`: (list(string), padrão: `["0.0.0.0/0"]`) CIDRs para acesso público ao endpoint.

### Grupos de Nós Gerenciados (Managed Node Groups)
*   `node_groups`: (Obrigatório, map(object)) Um mapa de objetos, onde cada objeto define um node group. A chave do mapa é um nome lógico para o grupo (ex: `default_pool`, `gpu_workers`).
    *   **Estrutura do objeto do node group:**
        *   `name`: (string, obrigatório) Nome único para o node group EKS.
        *   `instance_types`: (list(string), padrão: `["t3.medium"]`) Tipos de instância EC2.
        *   `desired_size`: (number, padrão: `2`) Número desejado de nós.
        *   `min_size`: (number, padrão: `1`) Número mínimo de nós para auto-scaling.
        *   `max_size`: (number, padrão: `3`) Número máximo de nós para auto-scaling.
        *   `disk_size`: (number, padrão: `20`) Tamanho do disco EBS (em GB).
        *   `subnet_ids`: (list(string), opcional) Sub-redes específicas para este node group (se omitido, usa `var.subnet_ids` do cluster).
        *   `ami_type`: (string, padrão: `AL2_x86_64`) Tipo de AMI (ex: `AL2_x86_64`, `AL2_x86_64_GPU`, `BOTTLEROCKET_ARM_64`).
        *   `labels`: (map(string), opcional) Labels do Kubernetes a serem aplicados aos nós.
        *   `taints`: (list(object), opcional) Taints a serem aplicados aos nós (objeto com `key`, `value`, `effect`).
        *   `tags`: (map(string), opcional) Tags AWS para o Auto Scaling Group do node group.
        *   `capacity_type`: (string, padrão: `ON_DEMAND`) Tipo de capacidade (`ON_DEMAND` ou `SPOT`).

### AWS Load Balancer Controller (LBC)
*   `enable_aws_load_balancer_controller`: (bool, padrão: `true`) Controla a instalação do AWS LBC.
*   `aws_load_balancer_controller_helm_chart_version`: (string, padrão: `1.7.1`) Versão do chart Helm do AWS LBC. (Verifique a versão mais recente recomendada).

### Nginx Ingress Controller
*   `enable_nginx_ingress_controller`: (bool, padrão: `true`) Controla a instalação do Nginx Ingress.
*   `nginx_ingress_helm_chart_version`: (string, padrão: `4.10.0`) Versão do chart Helm do Nginx Ingress. (Verifique a versão mais recente recomendada).
*   `nginx_ingress_replica_count`: (number, padrão: `2`) Número de réplicas para o controller Nginx.
*   `nginx_ingress_namespace`: (string, padrão: `ingress-nginx`) Namespace onde o Nginx Ingress será instalado.

### Segurança e Acesso (RBAC e `aws-auth`)
*   `manage_aws_auth_configmap`: (bool, padrão: `false`) Controla se o Terraform gerencia o ConfigMap `aws-auth`.
*   `map_additional_iam_roles_to_rbac`: (list(object), opcional, padrão: `[]`) Lista de objetos para mapear roles IAM adicionais no `aws-auth`.
    *   Estrutura do objeto: `rolearn` (string), `username` (string), `groups` (list(string)).
*   `map_additional_iam_users_to_rbac`: (list(object), opcional, padrão: `[]`) Lista de objetos para mapear usuários IAM adicionais.
    *   Estrutura do objeto: `userarn` (string), `username` (string), `groups` (list(string)).

### Logging de Containers (Fluent Bit)
*   `enable_container_logs_to_cloudwatch`: (bool, padrão: `true`) Controla a implantação do Fluent Bit.
*   `fluent_bit_cloudwatch_log_group_name`: (string, opcional) Nome do grupo de logs no CloudWatch. Se `null`, um nome padrão (`/aws/eks/${var.cluster_name}/containers`) será usado.
*   `fluent_bit_namespace`: (string, padrão: `amazon-cloudwatch`) Namespace para os recursos do Fluent Bit.

### Logging do Control Plane EKS
*   `enabled_cluster_log_types`: (list(string), padrão: `["api", "audit", "authenticator", "controllerManager", "scheduler"]`) Tipos de log do control plane a serem enviados para o CloudWatch.

## Saídas (Outputs)

Consulte o arquivo `outputs.tf` para a lista completa de saídas e suas descrições em português. As principais saídas incluem:

-   `cluster_arn`: ARN (Amazon Resource Name) do cluster EKS.
-   `cluster_endpoint`: Endpoint do servidor da API do Kubernetes para o cluster EKS.
-   `cluster_id`: ID do cluster EKS (geralmente o mesmo que o nome do cluster).
-   `cluster_iam_role_arn`: ARN da IAM role associada ao control plane do cluster EKS.
-   `cluster_oidc_issuer_url`: URL do provedor OIDC do cluster EKS, usada para IAM Roles for Service Accounts (IRSA).
-   `cluster_security_group_id`: ID do security group principal associado ao cluster EKS.
-   `cluster_version`: Versão do Kubernetes em execução no cluster EKS.
-   `node_group_arns`: Mapa dos ARNs dos grupos de nós EKS criados, indexados pelo nome lógico do grupo.
-   `node_group_names`: Mapa dos nomes dos grupos de nós EKS criados.
-   `node_group_iam_role_arns`: Mapa dos ARNs das IAM roles dos grupos de nós EKS.
-   `node_group_shared_iam_role_name`: Nome da IAM role compartilhada por todos os grupos de nós gerenciados.
-   `aws_load_balancer_controller_sa_role_arn`: ARN da IAM Role para a Service Account do AWS Load Balancer Controller (se habilitado).
-   `aws_load_balancer_controller_sa_name`: Nome da Service Account configurada para o AWS LBC (se habilitado).
-   `fluent_bit_cloudwatch_log_group`: Nome do grupo de logs do CloudWatch usado pelo Fluent Bit (se habilitado).
-   `fluent_bit_sa_role_arn`: ARN da IAM Role para a Service Account do Fluent Bit (se habilitado).
-   `fluent_bit_namespace_name`: Namespace onde os recursos do Fluent Bit estão implantados (se habilitado).
-   `nginx_ingress_controller_load_balancer_hostname`: Hostname do Load Balancer (NLB) para o Nginx Ingress Controller (se habilitado e o serviço for provisionado).

## Detalhes dos Componentes Adicionais

### AWS Load Balancer Controller (LBC)

-   **O que é?** O AWS Load Balancer Controller gerencia Elastic Load Balancers (ALBs e NLBs) para um cluster EKS. Ele satisfaz os recursos `Ingress` do Kubernetes para criar ALBs e os recursos `Service` do tipo `LoadBalancer` para criar NLBs (ou ALBs, dependendo das annotations).
-   **Ativação:** Controlado pela variável `enable_aws_load_balancer_controller` (padrão: `true`).
-   **Importância:** Essencial para expor aplicações de forma robusta e escalável na AWS, oferecendo funcionalidades como roteamento baseado em host/path (ALB), terminação SSL, e integração com Web Application Firewall (WAF).
-   **IRSA:** Este módulo configura automaticamente uma IAM Role e Service Account para o LBC usar IRSA, seguindo as melhores práticas de segurança.

### Nginx Ingress Controller

-   **O que é?** Um popular controlador de Ingress que usa o Nginx como um proxy reverso e balanceador de carga. Oferece funcionalidades avançadas de roteamento, reescrita de URL, autenticação, etc.
-   **Ativação:** Controlado pela variável `enable_nginx_ingress_controller` (padrão: `true`).
-   **Configuração neste Módulo:** Por padrão, o serviço do Nginx Ingress Controller é configurado para ser do tipo `LoadBalancer` com annotations para que o AWS LBC provisione um Network Load Balancer (NLB) para ele. Isso fornece um ponto de entrada de rede de alta performance para o Nginx.
-   **Exemplo de Recurso Ingress (para usar com Nginx):**
    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: minha-aplicacao-ingress
      namespace: minha-app-ns
      annotations:
        # Use 'nginx' como ingressClassName se você não tiver um default ou tiver múltiplos ingress controllers
        kubernetes.io/ingress.class: nginx
        # Exemplo de annotation para reescrita de target (útil se o serviço espera tráfego em /)
        # nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      rules:
      - host: minhaaplicacao.meudominio.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: meu-servico-aplicacao
                port:
                  number: 80
      # Opcional: Configuração TLS
      # tls:
      # - hosts:
      #   - minhaaplicacao.meudominio.com
      #   secretName: meu-certificado-tls-secret # Secret contendo o certificado e chave TLS
    ```

### Fluent Bit (Logging de Containers)

-   **O que é?** Um processador e encaminhador de logs leve e de alta performance.
-   **Ativação:** Controlado pela variável `enable_container_logs_to_cloudwatch` (padrão: `true`).
-   **Funcionamento:** Este módulo implanta o Fluent Bit como um DaemonSet (um pod em cada nó). Ele coleta os logs de todos os contêineres (`/var/log/containers/*.log`), enriquece-os com metadados do Kubernetes (como nome do pod, namespace, etc.) e os encaminha para o Amazon CloudWatch Logs.
-   **Configuração:**
    -   Os logs são enviados para um grupo de logs no CloudWatch, cujo nome pode ser personalizado com `var.fluent_bit_cloudwatch_log_group_name` ou usa o padrão `/aws/eks/${var.cluster_name}/containers`.
    -   A IAM Role para a Service Account do Fluent Bit (`fluent_bit_sa_role`) é criada com as permissões necessárias para escrever no CloudWatch Logs.
-   **Acessando os Logs:**
    1.  Navegue até o console do Amazon CloudWatch.
    2.  No menu à esquerda, vá em "Log groups".
    3.  Procure pelo grupo de logs com o nome configurado (ex: `/aws/eks/meu-cluster/containers`).
    4.  Dentro do grupo, você encontrará streams de logs, geralmente prefixados com `from-fluent-bit-`, contendo os logs dos seus contêineres.

### Gerenciamento de Acesso (`aws-auth` ConfigMap)

-   **Propósito:** O ConfigMap `aws-auth` no namespace `kube-system` é o mecanismo padrão no EKS para mapear identidades IAM (usuários e roles) para usuários e grupos dentro do sistema RBAC do Kubernetes.
-   **Gerenciamento via Módulo:**
    -   Se `var.manage_aws_auth_configmap` for `true`:
        -   O módulo criará e gerenciará o ConfigMap `aws-auth`.
        -   **Importante:** A IAM Role dos Node Groups (`eks_node_group_role`) é automaticamente adicionada à seção `mapRoles` para garantir que os nós possam se registrar no cluster.
        -   Use `var.map_additional_iam_roles_to_rbac` para adicionar outras roles IAM. Cada objeto na lista deve especificar `rolearn`, `username` (o nome de usuário que esta role representará no Kubernetes) e `groups` (uma lista de grupos RBAC, ex: `["system:masters"]` para acesso de administrador).
        -   Use `var.map_additional_iam_users_to_rbac` para adicionar usuários IAM. Cada objeto deve especificar `userarn`, `username` e `groups`.
-   **Exemplo de Mapeamento (em `variables.tf` ou no seu arquivo de definição do módulo):**
    ```terraform
    manage_aws_auth_configmap = true
    map_additional_iam_roles_to_rbac = [
      {
        rolearn  = "arn:aws:iam::112233445566:role/MyEKSAdminRole"
        username = "my-eks-admin-user" # Nome de usuário dentro do Kubernetes
        groups   = ["system:masters"]    # Concede permissões de administrador do cluster
      }
    ]
    map_additional_iam_users_to_rbac = [
      {
        userarn  = "arn:aws:iam::112233445566:user/DeveloperJohn"
        username = "john.doe"
        groups   = ["developers", "viewers"] # Grupos RBAC personalizados
      }
    ]
    ```
-   **Considerações:**
    -   Se você já tem um `aws-auth` ConfigMap existente e define `manage_aws_auth_configmap = true`, o Terraform tentará sobrescrevê-lo (devido a `force = true` no recurso `kubernetes_config_map_v1_data`). Tenha cuidado e faça backup se necessário.
    -   O usuário ou role IAM que criou o cluster EKS já tem permissões `system:masters` e não precisa ser adicionado ao `aws-auth` para acesso inicial.

## Considerações para Produção

Ao usar este módulo em um ambiente de produção, considere o seguinte:

-   **Tipos de Instância:** Escolha os tipos de instância para os Node Groups (`instance_types`) com base nos requisitos de CPU, memória e GPU das suas cargas de trabalho. Considere o uso de instâncias otimizadas para computação, memória ou com GPUs, conforme necessário.
-   **Alta Disponibilidade (HA):**
    -   Configure os Node Groups com `min_size` e `max_size` adequados para permitir o escalonamento automático. Distribua os nós em múltiplas Zonas de Disponibilidade (fornecendo sub-redes em diferentes AZs).
    -   Para componentes críticos como o Nginx Ingress Controller, use `nginx_ingress_replica_count` maior ou igual a 2.
-   **Escalonamento de Workloads:**
    -   Implemente o Horizontal Pod Autoscaler (HPA) para suas aplicações para escalar automaticamente o número de pods com base em métricas como uso de CPU ou memória.
    -   Considere o uso do Vertical Pod Autoscaler (VPA) para ajustar automaticamente as requests e limits de CPU/memória dos seus pods.
    -   O Cluster Autoscaler é geralmente gerenciado pelo EKS para os Managed Node Groups, ajustando o `desired_size` dos grupos com base na demanda de pods pendentes.
-   **Estratégias de Atualização:**
    -   **Control Plane:** O EKS gerencia as atualizações do control plane. Planeje as atualizações de versão do Kubernetes com antecedência.
    -   **Node Groups:** Use a funcionalidade de atualização de Node Groups do EKS, que permite atualizações graduais (rolling updates) para minimizar o impacto nas aplicações.
    -   **Aplicações e Add-ons:** Implemente estratégias de atualização seguras (ex: blue/green, canary) para suas aplicações e para os add-ons instalados via Helm (LBC, Nginx, Fluent Bit).
-   **Segurança de Segredos (Secrets):**
    -   Habilite a criptografia de segredos do Kubernetes no etcd usando uma Chave KMS gerenciada pelo cliente (Customer Managed Key - CMK). Isso pode ser configurado no recurso `aws_eks_cluster` através do argumento `encryption_config`. (Este módulo não implementa isso por padrão, mas é uma adição recomendada).
    -   Use o AWS Secrets Manager ou HashiCorp Vault para gerenciar segredos de aplicação e injetá-los nos pods de forma segura (ex: via CSI Secrets Store Driver).
-   **Monitoramento e Alertas:**
    -   Além do logging de containers com Fluent Bit, configure uma solução de monitoramento abrangente (ex: Prometheus e Grafana, ou Amazon Managed Service for Prometheus/Grafana).
    -   Configure alertas para métricas críticas do cluster, nós e aplicações.
-   **Políticas de Rede:** Implemente `NetworkPolicy` do Kubernetes para restringir o tráfego entre pods e namespaces, seguindo o princípio de menor privilégio.
-   **Custos:** Monitore os custos associados ao EKS (control plane, nós, tráfego de dados, load balancers, logs do CloudWatch, etc.) usando o AWS Cost Explorer e configure orçamentos.
-   **Backup e Recuperação:** Defina uma estratégia para backup e recuperação do estado das suas aplicações e, se necessário, do etcd (embora o EKS gerencie backups do etcd para o control plane). O Velero é uma ferramenta popular para backup e restauração de clusters Kubernetes.

## Exemplo de Uso Completo

Este exemplo demonstra a configuração de um cluster EKS com vários componentes habilitados, incluindo Node Groups, AWS Load Balancer Controller, Nginx Ingress Controller, Fluent Bit para logging, e gerenciamento do `aws-auth` ConfigMap.

```terraform
provider "aws" {
  region = "us-east-1" # Substitua pela sua região de preferência
}

# Obtém as zonas de disponibilidade disponíveis na região para distribuição de sub-redes/nós
data "aws_availability_zones" "available" {
  state = "available"
}

module "meu_cluster_eks_completo" {
  source = "./aws_blueprints/eks" # Ajuste o caminho conforme a estrutura do seu projeto

  # --- Configurações Gerais do Cluster ---
  cluster_name    = "eks-producao-app"
  cluster_version = "1.29" # Verifique a versão mais recente suportada pelo EKS e seus addons
  tags = {
    Environment = "Producao"
    Owner       = "EquipeApp"
    CostCenter  = "AppXYZ"
  }

  # --- Rede e Load Balancing ---
  vpc_id = "vpc-0123456789abcdef0" # Substitua pelo ID da sua VPC
  # Use sub-redes privadas em pelo menos duas AZs para alta disponibilidade
  subnet_ids = ["subnet-012345abcdef012345", "subnet-0fedcba9876543210"]

  # Acesso ao Endpoint API
  endpoint_private_access = true  # Recomendado para produção
  endpoint_public_access  = false # Restringir acesso público se possível

  # --- Logging do Control Plane ---
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # --- Grupos de Nós Gerenciados ---
  node_groups = {
    app_workers_ondemand = {
      name           = "app-ondemand-pool"
      instance_types = ["m5.large", "m5a.large"] # Lista de tipos de instância
      desired_size   = 3
      min_size       = 2
      max_size       = 5
      disk_size      = 50 # GB
      ami_type       = "AL2_x86_64"
      labels = {
        "workload-type" = "application"
        "lifecycle"     = "OnDemand"
      }
      tags = {
        "CustomTagNodeGroup" = "AppOnDemand"
      }
      # subnet_ids = ["subnet-privada-az1", "subnet-privada-az2"] # Opcional: se diferente de var.subnet_ids
    },
    # Exemplo de node group SPOT (opcional)
    # app_workers_spot = {
    #   name            = "app-spot-pool"
    #   instance_types  = ["t3.large", "t3a.large"]
    #   desired_size    = 1
    #   min_size        = 1
    #   max_size        = 4
    #   capacity_type   = "SPOT"
    #   labels          = { "workload-type" = "application", "lifecycle" = "Spot" }
    #   taints = [
    #     { key = "spotOnly", value = "true", effect = "PREFER_NO_SCHEDULE" }
    #   ]
    # }
  }

  # --- AWS Load Balancer Controller ---
  enable_aws_load_balancer_controller = true
  # aws_load_balancer_controller_helm_chart_version = "1.8.0" # Verifique a versão mais recente

  # --- Nginx Ingress Controller ---
  enable_nginx_ingress_controller = true
  # nginx_ingress_helm_chart_version = "4.10.1" # Verifique a versão mais recente
  nginx_ingress_replica_count   = 3
  nginx_ingress_namespace       = "kube-system-ingress" # Namespace customizado para Nginx

  # --- Fluent Bit (Logging de Containers) ---
  enable_container_logs_to_cloudwatch = true
  fluent_bit_cloudwatch_log_group_name = "/aws/eks/eks-producao-app/containers"
  fluent_bit_namespace                = "kube-system-logging" # Namespace customizado para Fluent Bit

  # --- Segurança e Acesso (aws-auth) ---
  manage_aws_auth_configmap = true
  map_additional_iam_roles_to_rbac = [
    {
      rolearn  = "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKSPowerUserRole" # Substitua YOUR_ACCOUNT_ID
      username = "poweruser-{{SessionName}}" # Template para nome de usuário
      groups   = ["system:masters"] # Concede acesso de administrador
    },
    {
      rolearn  = "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKSViewOnlyRole" # Substitua YOUR_ACCOUNT_ID
      username = "viewonly-{{SessionName}}"
      groups   = ["system:viewers"] # Grupo RBAC customizado ou padrão para visualização
    }
  ]
  map_additional_iam_users_to_rbac = [
    {
      userarn  = "arn:aws:iam::YOUR_ACCOUNT_ID:user/operations-user" # Substitua YOUR_ACCOUNT_ID
      username = "ops-user"
      groups   = ["system:config-readers", "operations-group"]
    }
  ]
}

# --- Saídas ---
output "eks_cluster_name" {
  description = "Nome do cluster EKS criado."
  value       = module.meu_cluster_eks_completo.cluster_id
}

output "eks_cluster_endpoint" {
  description = "Endpoint do API server do cluster EKS."
  value       = module.meu_cluster_eks_completo.cluster_endpoint
}

output "eks_cluster_oidc_provider_url" {
  description = "URL do provedor OIDC do cluster EKS (para IRSA)."
  value       = module.meu_cluster_eks_completo.cluster_oidc_issuer_url
}

output "eks_node_group_arns_map" {
  description = "Mapa dos ARNs dos Node Groups criados."
  value       = module.meu_cluster_eks_completo.node_group_arns
}

output "nginx_ingress_load_balancer" {
  description = "Hostname do Load Balancer para o Nginx Ingress Controller."
  value       = module.meu_cluster_eks_completo.nginx_ingress_controller_load_balancer_hostname
}

output "cloudwatch_log_group_fluent_bit" {
  description = "Grupo de Logs do CloudWatch para logs de contêineres do Fluent Bit."
  value       = module.meu_cluster_eks_completo.fluent_bit_cloudwatch_log_group
}
```
