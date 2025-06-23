#!/bin/bash

# ==============================================
# 🚀 HAWLS Panel - Evolution API Template
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
EVOLUTION_DOMAIN="${1:-evolution.seudominio.com}"
EVOLUTION_DB_PASSWORD="${2:-$(openssl rand -base64 32)}"
POSTGRES_PASSWORD="${3:-$(openssl rand -base64 32)}"
REDIS_PASSWORD="${4:-$(openssl rand -base64 32)}"
WEBHOOK_DOMAIN="${5:-webhook.seudominio.com}"
API_KEY="${6:-$(openssl rand -base64 32)}"
NETWORK_NAME="${7:-hawls-network}"

# Criar diretório
mkdir -p /opt/evolution-api

# Criar docker-compose.yml
cat > /opt/evolution-api/docker-compose.yml << EOF
version: '3.8'

services:
  evolution-api:
    image: atendai/evolution-api:v2.0.0
    container_name: evolution-api
    restart: unless-stopped
    environment:
      # Database
      DATABASE_ENABLED: true
      DATABASE_CONNECTION_URI: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/evolution
      DATABASE_CONNECTION_CLIENT_NAME: evolution
      DATABASE_SAVE_DATA_INSTANCE: true
      DATABASE_SAVE_DATA_NEW_MESSAGE: true
      DATABASE_SAVE_MESSAGE_UPDATE: true
      DATABASE_SAVE_DATA_CONTACTS: true
      DATABASE_SAVE_DATA_CHATS: true
      
      # Redis
      REDIS_ENABLED: true
      REDIS_URI: redis://:${REDIS_PASSWORD}@redis:6379
      REDIS_PREFIX_KEY: evolution
      
      # Server
      SERVER_TYPE: http
      SERVER_PORT: 8080
      SERVER_URL: https://${EVOLUTION_DOMAIN}
      
      # Cors
      CORS_ORIGIN: "*"
      CORS_METHODS: "GET,POST,PUT,DELETE"
      CORS_CREDENTIALS: true
      
      # Log
      LOG_LEVEL: ERROR
      LOG_COLOR: true
      LOG_BAILEYS: error
      
      # Instance
      DEL_INSTANCE: false
      DEL_TEMP_INSTANCES: true
      
      # Events
      EVENTS_APPLICATION_STARTUP: false
      EVENTS_QRCODE_UPDATED: true
      EVENTS_MESSAGES_SET: true
      EVENTS_MESSAGES_UPSERT: true
      EVENTS_MESSAGES_UPDATE: true
      EVENTS_MESSAGES_DELETE: true
      EVENTS_SEND_MESSAGE: true
      EVENTS_CONTACTS_SET: true
      EVENTS_CONTACTS_UPSERT: true
      EVENTS_CONTACTS_UPDATE: true
      EVENTS_PRESENCE_UPDATE: true
      EVENTS_CHATS_SET: true
      EVENTS_CHATS_UPSERT: true
      EVENTS_CHATS_UPDATE: true
      EVENTS_CHATS_DELETE: true
      EVENTS_GROUPS_UPSERT: true
      EVENTS_GROUP_UPDATE: true
      EVENTS_GROUP_PARTICIPANTS_UPDATE: true
      EVENTS_CONNECTION_UPDATE: true
      EVENTS_CALL: true
      
      # Webhook
      WEBHOOK_GLOBAL_URL: https://${WEBHOOK_DOMAIN}
      WEBHOOK_GLOBAL_ENABLED: true
      WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS: false
      
      # Config
      CONFIG_SESSION_PHONE_CLIENT: Evolution API
      CONFIG_SESSION_PHONE_NAME: Chrome
      
      # QR Code
      QRCODE_LIMIT: 30
      QRCODE_COLOR: "#198754"
      
      # Authentication
      AUTHENTICATION_TYPE: apikey
      AUTHENTICATION_API_KEY: ${API_KEY}
      AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES: true
      
      # Language
      LANGUAGE: pt-BR
      
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - postgres
      - redis
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.evolution.rule=Host(\`${EVOLUTION_DOMAIN}\`)"
      - "traefik.http.routers.evolution.tls=true"
      - "traefik.http.routers.evolution.tls.certresolver=letsencrypt"
      - "traefik.http.services.evolution.loadbalancer.server.port=8080"

  postgres:
    image: postgres:15-alpine
    container_name: evolution-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: evolution
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${NETWORK_NAME}

  redis:
    image: redis:7-alpine
    container_name: evolution-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - ${NETWORK_NAME}

volumes:
  evolution_instances:
  evolution_store:
  postgres_data:
  redis_data:

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Iniciar serviços
log_info "Iniciando Evolution API..."
cd /opt/evolution-api
docker compose up -d

# Aguardar inicialização
log_info "Aguardando inicialização dos serviços..."
sleep 30

# Criar arquivo de informações
log_info "Criando arquivo de informações..."
mkdir -p /root/hawls-info

cat > /root/hawls-info/evolution-api-info.txt << INFO_EOF
[ EVOLUTION API ]

Domínio da API: https://${EVOLUTION_DOMAIN}

Domínio do Webhook: https://${WEBHOOK_DOMAIN}

API Key: ${API_KEY}

Documentação: https://${EVOLUTION_DOMAIN}/manager

=== BANCO DE DADOS ===
Host: postgres
Porta: 5432
Database: evolution
Usuário: postgres
Senha: ${POSTGRES_PASSWORD}

=== REDIS ===
Host: redis
Porta: 6379
Senha: ${REDIS_PASSWORD}

=== COMANDOS ÚTEIS ===
Ver logs da API: docker logs evolution-api
Ver logs do Postgres: docker logs evolution-postgres
Ver logs do Redis: docker logs evolution-redis
Reiniciar API: cd /opt/evolution-api && docker compose restart evolution-api
Reiniciar todos: cd /opt/evolution-api && docker compose restart
Parar todos: cd /opt/evolution-api && docker compose down
Iniciar todos: cd /opt/evolution-api && docker compose up -d

=== ESTRUTURA DE DIRETÓRIOS ===
/opt/evolution-api/ - Configuração da Evolution API
/root/hawls-info/ - Informações do servidor

=== COMO USAR ===
1. Acesse: https://${EVOLUTION_DOMAIN}/manager
2. Use a API Key: ${API_KEY}
3. Crie uma instância
4. Escaneie o QR Code
5. Configure webhooks se necessário

Instalação concluída em: $(date)
Script gerado pelo HAWLS Panel
INFO_EOF

# Verificar se está rodando
if docker ps | grep -q evolution-api; then
    log_success "Evolution API instalada e rodando!"
    echo
    echo -e "${GREEN}📋 INFORMAÇÕES DE ACESSO:${NC}"
    echo -e "${BLUE}🌐 Evolution API: https://${EVOLUTION_DOMAIN}${NC}"
    echo -e "${BLUE}🔗 Manager: https://${EVOLUTION_DOMAIN}/manager${NC}"
    echo -e "${BLUE}🔑 API Key: ${API_KEY}${NC}"
    echo -e "${BLUE}📡 Webhook: https://${WEBHOOK_DOMAIN}${NC}"
    echo
    echo -e "${YELLOW}📁 Arquivo de informações salvo em: /root/hawls-info/evolution-api-info.txt${NC}"
else
    log_error "Erro na instalação da Evolution API"
    exit 1
fi

log_success "Evolution API configurada com sucesso!" 