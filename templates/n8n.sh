#!/bin/bash

# ==============================================
# 🚀 HAWLS Panel - N8N Template
# ==============================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parâmetros (passados pelo script principal)
N8N_DOMAIN="${1:-n8n.seudominio.com}"
WEBHOOK_DOMAIN="${2:-webhook.seudominio.com}"
POSTGRES_PASSWORD="${3:-$(openssl rand -base64 32)}"
N8N_ENCRYPTION_KEY="${4:-$(openssl rand -base64 32)}"
NETWORK_NAME="${5:-hawls-network}"

# Criar diretório
mkdir -p /opt/n8n

# Criar docker-compose.yml
cat > /opt/n8n/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      # Database
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: postgres
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      
      # General
      N8N_HOST: ${N8N_DOMAIN}
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://${WEBHOOK_DOMAIN}
      N8N_EDITOR_BASE_URL: https://${N8N_DOMAIN}
      
      # Security
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      
      # Features
      N8N_PERSONALIZATION_ENABLED: true
      N8N_VERSION_NOTIFICATIONS_ENABLED: true
      N8N_DIAGNOSTICS_ENABLED: false
      N8N_HIRING_BANNER_ENABLED: false
      
      # Templates
      N8N_TEMPLATES_ENABLED: true
      N8N_TEMPLATES_HOST: https://api.n8n.io/api/
      
      # User Management
      N8N_USER_MANAGEMENT_DISABLED: false
      N8N_USER_MANAGEMENT_JWT_SECRET: ${N8N_ENCRYPTION_KEY}
      
      # Executions
      EXECUTIONS_PROCESS: main
      EXECUTIONS_DATA_SAVE_ON_ERROR: all
      EXECUTIONS_DATA_SAVE_ON_SUCCESS: all
      EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS: true
      
      # Timezone
      GENERIC_TIMEZONE: America/Sao_Paulo
      TZ: America/Sao_Paulo
      
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - postgres
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`${N8N_DOMAIN}\`)"
      - "traefik.http.routers.n8n.tls=true"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
      
      # Webhook routing
      - "traefik.http.routers.n8n-webhook.rule=Host(\`${WEBHOOK_DOMAIN}\`)"
      - "traefik.http.routers.n8n-webhook.tls=true"
      - "traefik.http.routers.n8n-webhook.tls.certresolver=letsencrypt"
      - "traefik.http.routers.n8n-webhook.service=n8n"

  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${NETWORK_NAME}

volumes:
  n8n_data:
  postgres_data:

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Iniciar serviços
log_info "Iniciando N8N..."
cd /opt/n8n
docker compose up -d

# Aguardar inicialização
log_info "Aguardando inicialização dos serviços..."
sleep 30

# Criar arquivo de informações
log_info "Criando arquivo de informações..."
mkdir -p /root/hawls-info

cat > /root/hawls-info/n8n-info.txt << INFO_EOF
[ N8N ]

Domínio do N8N: https://${N8N_DOMAIN}

Domínio do Webhook do N8N: https://${WEBHOOK_DOMAIN}

Email: Precisa criar no primeiro acesso do N8N

Senha: Precisa criar no primeiro acesso do N8N

=== BANCO DE DADOS ===
Host: postgres
Porta: 5432
Database: n8n
Usuário: postgres
Senha: ${POSTGRES_PASSWORD}

=== CONFIGURAÇÕES AVANÇADAS ===
Encryption Key: ${N8N_ENCRYPTION_KEY}
Timezone: America/Sao_Paulo
User Management: Habilitado
Templates: Habilitado

=== COMANDOS ÚTEIS ===
Ver logs do N8N: docker logs n8n
Ver logs do Postgres: docker logs n8n-postgres
Reiniciar N8N: cd /opt/n8n && docker compose restart n8n
Reiniciar todos: cd /opt/n8n && docker compose restart
Parar todos: cd /opt/n8n && docker compose down
Iniciar todos: cd /opt/n8n && docker compose up -d
Backup dados: docker exec n8n-postgres pg_dump -U postgres n8n > n8n_backup.sql

=== ESTRUTURA DE DIRETÓRIOS ===
/opt/n8n/ - Configuração do N8N
/root/hawls-info/ - Informações do servidor

=== COMO USAR ===
1. Acesse: https://${N8N_DOMAIN}
2. Crie sua conta de administrador no primeiro acesso
3. Configure workflows
4. Use webhooks em: https://${WEBHOOK_DOMAIN}
5. Explore templates disponíveis

=== WEBHOOKS ===
URL base para webhooks: https://${WEBHOOK_DOMAIN}
Exemplo de webhook: https://${WEBHOOK_DOMAIN}/webhook/seu-webhook-id

Instalação concluída em: $(date)
Script gerado pelo HAWLS Panel
INFO_EOF

# Verificar se está rodando
if docker ps | grep -q n8n; then
    log_success "N8N instalado e rodando!"
    echo
    echo -e "${GREEN}📋 INFORMAÇÕES DE ACESSO:${NC}"
    echo -e "${BLUE}🌐 N8N: https://${N8N_DOMAIN}${NC}"
    echo -e "${BLUE}📡 Webhooks: https://${WEBHOOK_DOMAIN}${NC}"
    echo -e "${BLUE}👤 Configure usuário no primeiro acesso${NC}"
    echo
    echo -e "${YELLOW}📁 Arquivo de informações salvo em: /root/hawls-info/n8n-info.txt${NC}"
else
    log_error "Erro na instalação do N8N"
    exit 1
fi

log_success "N8N configurado com sucesso!" 