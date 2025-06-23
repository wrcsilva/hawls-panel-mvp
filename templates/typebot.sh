#!/bin/bash

# ==============================================
# 🚀 HAWLS Panel - Typebot Template
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
TYPEBOT_DOMAIN="${1:-typebot.seudominio.com}"
VIEWER_DOMAIN="${2:-viewer.seudominio.com}"
POSTGRES_PASSWORD="${3:-$(openssl rand -base64 32)}"
NEXTAUTH_SECRET="${4:-$(openssl rand -base64 32)}"
ENCRYPTION_SECRET="${5:-$(openssl rand -base64 32)}"
ADMIN_EMAIL="${6:-admin@seudominio.com}"
NETWORK_NAME="${7:-hawls-network}"

# Criar diretório
mkdir -p /opt/typebot

# Criar docker-compose.yml
cat > /opt/typebot/docker-compose.yml << EOF
version: '3.8'

services:
  typebot-builder:
    image: baptistearno/typebot-builder:latest
    container_name: typebot-builder
    restart: unless-stopped
    environment:
      # Database
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/typebot
      
      # URLs
      NEXTAUTH_URL: https://${TYPEBOT_DOMAIN}
      NEXT_PUBLIC_VIEWER_URL: https://${VIEWER_DOMAIN}
      
      # Security
      NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}
      ENCRYPTION_SECRET: ${ENCRYPTION_SECRET}
      
      # Admin
      ADMIN_EMAIL: ${ADMIN_EMAIL}
      
      # Features
      DISABLE_SIGNUP: false
      NEXT_PUBLIC_DISABLE_SIGNUP: false
      
      # S3 (opcional - desabilitado)
      S3_ENDPOINT: 
      S3_ACCESS_KEY: 
      S3_SECRET_KEY: 
      S3_BUCKET: 
      
      # SMTP (configure se necessário)
      SMTP_HOST: 
      SMTP_PORT: 587
      SMTP_USERNAME: 
      SMTP_PASSWORD: 
      SMTP_SECURE: false
      SMTP_FROM_EMAIL: ${ADMIN_EMAIL}
      
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - postgres
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.typebot-builder.rule=Host(\`${TYPEBOT_DOMAIN}\`)"
      - "traefik.http.routers.typebot-builder.tls=true"
      - "traefik.http.routers.typebot-builder.tls.certresolver=letsencrypt"
      - "traefik.http.services.typebot-builder.loadbalancer.server.port=3000"

  typebot-viewer:
    image: baptistearno/typebot-viewer:latest
    container_name: typebot-viewer
    restart: unless-stopped
    environment:
      # Database
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/typebot
      
      # URLs
      NEXTAUTH_URL: https://${TYPEBOT_DOMAIN}
      NEXT_PUBLIC_VIEWER_URL: https://${VIEWER_DOMAIN}
      
      # Security
      ENCRYPTION_SECRET: ${ENCRYPTION_SECRET}
      
      # S3 (opcional - desabilitado)
      S3_ENDPOINT: 
      S3_ACCESS_KEY: 
      S3_SECRET_KEY: 
      S3_BUCKET: 
      
    networks:
      - ${NETWORK_NAME}
    depends_on:
      - postgres
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.typebot-viewer.rule=Host(\`${VIEWER_DOMAIN}\`)"
      - "traefik.http.routers.typebot-viewer.tls=true"
      - "traefik.http.routers.typebot-viewer.tls.certresolver=letsencrypt"
      - "traefik.http.services.typebot-viewer.loadbalancer.server.port=3000"

  postgres:
    image: postgres:15-alpine
    container_name: typebot-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: typebot
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${NETWORK_NAME}

volumes:
  postgres_data:

networks:
  ${NETWORK_NAME}:
    external: true
EOF

# Iniciar serviços
log_info "Iniciando Typebot..."
cd /opt/typebot
docker compose up -d

# Aguardar inicialização
log_info "Aguardando inicialização dos serviços..."
sleep 30

# Criar arquivo de informações
log_info "Criando arquivo de informações..."
mkdir -p /root/hawls-info

cat > /root/hawls-info/typebot-info.txt << INFO_EOF
[ TYPEBOT ]

Domínio do Builder: https://${TYPEBOT_DOMAIN}

Domínio do Viewer: https://${VIEWER_DOMAIN}

Email do Admin: ${ADMIN_EMAIL}

Senha: Defina na primeira configuração

=== BANCO DE DADOS ===
Host: postgres
Porta: 5432
Database: typebot
Usuário: postgres
Senha: ${POSTGRES_PASSWORD}

=== CONFIGURAÇÕES AVANÇADAS ===
NextAuth Secret: ${NEXTAUTH_SECRET}
Encryption Secret: ${ENCRYPTION_SECRET}
Signup: Habilitado (pode ser desabilitado)

=== COMANDOS ÚTEIS ===
Ver logs do Builder: docker logs typebot-builder
Ver logs do Viewer: docker logs typebot-viewer
Ver logs do Postgres: docker logs typebot-postgres
Reiniciar Builder: cd /opt/typebot && docker compose restart typebot-builder
Reiniciar Viewer: cd /opt/typebot && docker compose restart typebot-viewer
Reiniciar todos: cd /opt/typebot && docker compose restart
Parar todos: cd /opt/typebot && docker compose down
Iniciar todos: cd /opt/typebot && docker compose up -d
Backup dados: docker exec typebot-postgres pg_dump -U postgres typebot > typebot_backup.sql

=== ESTRUTURA DE DIRETÓRIOS ===
/opt/typebot/ - Configuração do Typebot
/root/hawls-info/ - Informações do servidor

=== COMO USAR ===
1. Acesse o Builder: https://${TYPEBOT_DOMAIN}
2. Crie sua conta (primeiro usuário será admin)
3. Configure seus chatbots
4. Publique e compartilhe via: https://${VIEWER_DOMAIN}
5. Configure integrações (WhatsApp, Telegram, etc.)

=== CONFIGURAÇÕES ADICIONAIS ===
Para configurar SMTP (emails):
1. Edite o docker-compose.yml
2. Configure SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD
3. Reinicie os containers

Para configurar S3 (arquivos):
1. Configure S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET
2. Reinicie os containers

Instalação concluída em: $(date)
Script gerado pelo HAWLS Panel
INFO_EOF

# Verificar se está rodando
if docker ps | grep -q typebot-builder && docker ps | grep -q typebot-viewer; then
    log_success "Typebot instalado e rodando!"
    echo
    echo -e "${GREEN}📋 INFORMAÇÕES DE ACESSO:${NC}"
    echo -e "${BLUE}🌐 Builder: https://${TYPEBOT_DOMAIN}${NC}"
    echo -e "${BLUE}👁️  Viewer: https://${VIEWER_DOMAIN}${NC}"
    echo -e "${BLUE}👤 Admin: ${ADMIN_EMAIL}${NC}"
    echo -e "${BLUE}🔧 Configure sua conta no primeiro acesso${NC}"
    echo
    echo -e "${YELLOW}📁 Arquivo de informações salvo em: /root/hawls-info/typebot-info.txt${NC}"
else
    log_error "Erro na instalação do Typebot"
    exit 1
fi

log_success "Typebot configurado com sucesso!" 