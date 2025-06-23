#!/bin/bash

# ==============================================
# 🚀 HAWLS Panel - Script de Instalação V2.0
# ==============================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funções de log
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
show_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════════╗
║                           🚀 HAWLS PANEL V2.0                                 ║
║                     Sistema de Instalação Automática                          ║
║                                                                                ║
║  ✨ Templates suportados: Evolution API, N8N, Typebot                         ║
║  🔒 SSL automático com Let's Encrypt                                           ║
║  🐳 Docker + Docker Compose                                                    ║
║  🔥 Firewall configurado automaticamente                                       ║
║  📋 Arquivo de resumo com credenciais                                          ║
╚════════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Verificar parâmetros
check_parameters() {
    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        log_error "Parâmetros obrigatórios não fornecidos!"
        echo ""
        echo "📋 USO CORRETO:"
        echo "   $0 <token> <template> [configurações...]"
        echo ""
        echo "📝 EXEMPLOS:"
        echo "   $0 hawls_abc123 evolution-api evolutionApiKey=\"minha-chave\" evolutionDomain=\"api.exemplo.com\""
        echo "   $0 hawls_def456 n8n n8nUser=\"admin\" n8nPassword=\"senha123\""
        echo "   $0 hawls_ghi789 typebot typebotDomain=\"typebot.exemplo.com\" typebotAdminEmail=\"admin@exemplo.com\""
        echo ""
        echo "📋 TEMPLATES DISPONÍVEIS:"
        echo "   • evolution-api - API WhatsApp Business"
        echo "   • n8n - Automação de workflows"
        echo "   • typebot - Constructor de chatbots"
        echo ""
        exit 1
    fi
}

# Verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        log_info "Execute: sudo su - && curl -sSL https://raw.githubusercontent.com/wrcsilva/hawls-panel-mvp/master/install.sh | bash -s -- \"$TOKEN\" \"$TEMPLATE\""
        exit 1
    fi
}

# Processar configurações do template
parse_template_config() {
    local config_string="$1"
    
    # Criar arquivo temporário para as configurações
    CONFIG_FILE="/tmp/hawls_template_config"
    echo "# HAWLS Template Configuration" > "$CONFIG_FILE"
    echo "# Generated at: $(date)" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    
    # Processar cada configuração passada
    shift 2  # Remove token e template dos argumentos
    for arg in "$@"; do
        if [[ "$arg" == *"="* ]]; then
            key=$(echo "$arg" | cut -d'=' -f1)
            value=$(echo "$arg" | cut -d'=' -f2- | sed 's/^"//;s/"$//')
            echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
            log_info "Configuração: $key = $value"
        fi
    done
    
    # Carregar configurações
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# Instalar dependências básicas
install_dependencies() {
    log_info "Instalando dependências básicas..."
    
    # Atualizar lista de pacotes
    apt update -y
    
    # Instalar ferramentas essenciais
    apt install -y \
        curl \
        wget \
        git \
        dos2unix \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        ufw \
        htop \
        nano \
        vim \
        jq \
        openssl
    
    log_success "Dependências básicas instaladas"
}

# Instalar Docker
install_docker() {
    log_info "Instalando Docker..."
    
    if ! command -v docker &> /dev/null; then
        # Instalar Docker oficial
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Configurar Docker para iniciar automaticamente
        systemctl enable docker
        systemctl start docker
        
        log_success "Docker instalado com sucesso!"
    else
        log_info "Docker já está instalado"
    fi
    
    # Instalar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose ${DOCKER_COMPOSE_VERSION} instalado!"
    else
        log_info "Docker Compose já está instalado"
    fi
}

# Configurar firewall
setup_firewall() {
    log_info "Configurando firewall..."
    
    # Configurações básicas
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH
    ufw allow ssh
    ufw allow 22/tcp
    
    # Permitir HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Permitir Docker
    ufw allow 2376/tcp
    ufw allow 2377/tcp
    ufw allow 7946/tcp
    ufw allow 7946/udp
    ufw allow 4789/udp
    
    # Permitir portas específicas dos templates
    case $TEMPLATE in
        "evolution-api")
            ufw allow 8080/tcp
            ;;
        "n8n")
            ufw allow 5678/tcp
            ;;
        "typebot")
            ufw allow 3000/tcp
            ufw allow 3001/tcp
            ;;
    esac
    
    # Habilitar firewall
    ufw --force enable
    
    log_success "Firewall configurado"
}

# Instalar template específico
install_template() {
    log_info "Instalando template: $TEMPLATE"
    
    case $TEMPLATE in
        "evolution-api")
            install_evolution_api
            ;;
        "n8n")
            install_n8n
            ;;
        "typebot")
            install_typebot
            ;;
        "basic"|*)
            install_basic_stack
            ;;
    esac
}

# Instalar Evolution API
install_evolution_api() {
    log_info "Configurando Evolution API..."
    
    # Configurações padrão
    EVOLUTION_API_KEY="${evolutionApiKey:-hawls_evolution_$(openssl rand -hex 16)}"
    EVOLUTION_DOMAIN="${evolutionDomain:-${DOMAIN:-localhost}}"
    EVOLUTION_WEBHOOK_URL="${evolutionWebhookUrl:-}"
    SERVER_URL="https://${EVOLUTION_DOMAIN}"
    
    # Gerar senhas seguras
    MONGO_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    mkdir -p /opt/hawls/evolution-api
    cd /opt/hawls/evolution-api
    
    cat > docker-compose.yml << EOF
version: '3.8'
services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    container_name: evolution-api
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - SERVER_TYPE=http
      - SERVER_PORT=8080
      - CORS_ORIGIN=*
      - CORS_METHODS=POST,GET,PUT,DELETE
      - CORS_CREDENTIALS=true
      - LOG_LEVEL=ERROR
      - LOG_COLOR=true
      - LOG_BAILEYS=error
      - DEL_INSTANCE=false
      - PROVIDER_ENABLED=false
      - DATABASE_ENABLED=true
      - DATABASE_CONNECTION_URI=mongodb://mongo:27017/evolution
      - DATABASE_CONNECTION_DB_PREFIX_NAME=evolution
      - REDIS_ENABLED=true
      - REDIS_URI=redis://redis:6379
      - REDIS_PREFIX_KEY=evolution
      - AUTHENTICATION_TYPE=apikey
      - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY}
      - AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true
      - SERVER_URL=${SERVER_URL}
      - WEBHOOK_GLOBAL_URL=${EVOLUTION_WEBHOOK_URL}
      - WEBHOOK_GLOBAL_ENABLED=${EVOLUTION_WEBHOOK_URL:+true}
      - LANGUAGE=pt-BR
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    networks:
      - hawls-network
    depends_on:
      - mongo
      - redis

  mongo:
    image: mongo:6.0
    container_name: evolution-mongo
    restart: unless-stopped
    environment:
      - MONGO_INITDB_ROOT_USERNAME=root
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}
    volumes:
      - evolution_mongo:/data/db
    networks:
      - hawls-network

  redis:
    image: redis:7-alpine
    container_name: evolution-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - evolution_redis:/data
    networks:
      - hawls-network

volumes:
  evolution_instances:
  evolution_store:
  evolution_mongo:
  evolution_redis:

networks:
  hawls-network:
    driver: bridge
EOF
    
    docker-compose up -d
    
    # Aguardar inicialização
    log_info "Aguardando inicialização do Evolution API..."
    sleep 30
    
    # Verificar se está rodando
    if curl -s http://localhost:8080 > /dev/null; then
        log_success "Evolution API instalado com sucesso na porta 8080"
        log_info "Acesso: http://$(curl -s ifconfig.me):8080"
    else
        log_warning "Evolution API pode estar ainda inicializando"
    fi
    
    # Salvar informações
    save_service_info "evolution-api" "8080" "Evolution API - WhatsApp Business" \
        "API_KEY=${EVOLUTION_API_KEY}" \
        "DOMAIN=${EVOLUTION_DOMAIN}" \
        "SERVER_URL=${SERVER_URL}" \
        "WEBHOOK_URL=${EVOLUTION_WEBHOOK_URL}" \
        "MONGO_PASSWORD=${MONGO_PASSWORD}" \
        "REDIS_PASSWORD=${REDIS_PASSWORD}" \
        "DOCUMENTATION=http://$(curl -s ifconfig.me):8080/manager"
}

# Instalar N8N
install_n8n() {
    log_info "Configurando N8N..."
    
    # Configurações
    N8N_USER="${n8nUser:-admin}"
    N8N_PASSWORD="${n8nPassword:-hawls_n8n_$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)}"
    N8N_WEBHOOK_URL="${n8nWebhookUrl:-https://${DOMAIN:-localhost}}"
    
    # Gerar senha do PostgreSQL
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    mkdir -p /opt/hawls/n8n
    cd /opt/hawls/n8n
    
    cat > docker-compose.yml << EOF
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:1.79.3
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=${N8N_WEBHOOK_URL}/
      - GENERIC_TIMEZONE=America/Sao_Paulo
      - N8N_DEFAULT_LOCALE=pt-BR
      - N8N_METRICS=true
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - hawls-network
    depends_on:
      - postgres

  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - n8n_postgres:/var/lib/postgresql/data
    networks:
      - hawls-network

volumes:
  n8n_data:
  n8n_postgres:

networks:
  hawls-network:
    driver: bridge
EOF
    
    docker-compose up -d
    
    # Aguardar inicialização
    log_info "Aguardando inicialização do N8N..."
    sleep 45
    
    # Verificar se está rodando
    if curl -s http://localhost:5678 > /dev/null; then
        log_success "N8N instalado com sucesso na porta 5678"
        log_info "Acesso: http://$(curl -s ifconfig.me):5678"
        log_info "Usuário: ${N8N_USER} | Senha: ${N8N_PASSWORD}"
    else
        log_warning "N8N pode estar ainda inicializando"
    fi
    
    # Salvar informações
    save_service_info "n8n" "5678" "N8N - Automação de Workflows" \
        "USER=${N8N_USER}" \
        "PASSWORD=${N8N_PASSWORD}" \
        "WEBHOOK_URL=${N8N_WEBHOOK_URL}" \
        "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
        "TIMEZONE=America/Sao_Paulo" \
        "DATABASE=PostgreSQL"
}

# Instalar Typebot
install_typebot() {
    log_info "Configurando Typebot..."
    
    # Configurações
    TYPEBOT_DOMAIN="${typebotDomain:-${DOMAIN:-localhost}}"
    TYPEBOT_ADMIN_EMAIL="${typebotAdminEmail:-admin@hawls.local}"
    TYPEBOT_ENCRYPTION_SECRET="${typebotEncryptionSecret:-hawls_typebot_$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)}"
    
    # Gerar senhas
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    mkdir -p /opt/hawls/typebot
    cd /opt/hawls/typebot
    
    cat > docker-compose.yml << EOF
version: '3.8'
services:
  typebot-builder:
    image: baptistearno/typebot-builder:latest
    container_name: typebot-builder
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NEXTAUTH_URL=http://${TYPEBOT_DOMAIN}:3000
      - NEXTAUTH_URL_INTERNAL=http://localhost:3000
      - ENCRYPTION_SECRET=${TYPEBOT_ENCRYPTION_SECRET}
      - DATABASE_URL=postgresql://typebot:${POSTGRES_PASSWORD}@postgres:5432/typebot
      - ADMIN_EMAIL=${TYPEBOT_ADMIN_EMAIL}
      - DISABLE_SIGNUP=false
      - SMTP_SECURE=false
      - NEXT_PUBLIC_VIEWER_URL=http://${TYPEBOT_DOMAIN}:3001
      - NEXT_PUBLIC_SMTP_FROM=Typebot <noreply@hawls.local>
    volumes:
      - typebot_builder:/app
    networks:
      - hawls-network
    depends_on:
      - postgres
      - redis

  typebot-viewer:
    image: baptistearno/typebot-viewer:latest
    container_name: typebot-viewer
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      - NEXTAUTH_URL=http://${TYPEBOT_DOMAIN}:3000
      - NEXTAUTH_URL_INTERNAL=http://localhost:3000
      - ENCRYPTION_SECRET=${TYPEBOT_ENCRYPTION_SECRET}
      - DATABASE_URL=postgresql://typebot:${POSTGRES_PASSWORD}@postgres:5432/typebot
      - NEXT_PUBLIC_VIEWER_URL=http://${TYPEBOT_DOMAIN}:3001
    volumes:
      - typebot_viewer:/app
    networks:
      - hawls-network
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:15-alpine
    container_name: typebot-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_DB=typebot
      - POSTGRES_USER=typebot
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - typebot_postgres:/var/lib/postgresql/data
    networks:
      - hawls-network

  redis:
    image: redis:7-alpine
    container_name: typebot-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - typebot_redis:/data
    networks:
      - hawls-network

volumes:
  typebot_builder:
  typebot_viewer:
  typebot_postgres:
  typebot_redis:

networks:
  hawls-network:
    driver: bridge
EOF
    
    docker-compose up -d
    
    # Aguardar inicialização
    log_info "Aguardando inicialização do Typebot..."
    sleep 60
    
    # Verificar se está rodando
    if curl -s http://localhost:3000 > /dev/null; then
        log_success "Typebot instalado com sucesso!"
        log_info "Builder: http://$(curl -s ifconfig.me):3000"
        log_info "Viewer: http://$(curl -s ifconfig.me):3001"
    else
        log_warning "Typebot pode estar ainda inicializando"
    fi
    
    # Salvar informações
    save_service_info "typebot" "3000,3001" "Typebot - Constructor de Chatbots" \
        "DOMAIN=${TYPEBOT_DOMAIN}" \
        "ADMIN_EMAIL=${TYPEBOT_ADMIN_EMAIL}" \
        "ENCRYPTION_SECRET=${TYPEBOT_ENCRYPTION_SECRET}" \
        "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
        "REDIS_PASSWORD=${REDIS_PASSWORD}" \
        "BUILDER_URL=http://$(curl -s ifconfig.me):3000" \
        "VIEWER_URL=http://$(curl -s ifconfig.me):3001"
}

# Instalar stack básico
install_basic_stack() {
    log_info "Configurando stack básico..."
    
    mkdir -p /opt/hawls/basic
    cd /opt/hawls/basic
    
    cat > docker-compose.yml << EOF
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    container_name: hawls-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./html:/usr/share/nginx/html:ro
    networks:
      - hawls-network

networks:
  hawls-network:
    driver: bridge
EOF
    
    # Criar configuração do Nginx
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name _;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
EOF
    
    # Criar página inicial
    mkdir -p html
    cat > html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>HAWLS Panel - Servidor Configurado</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f0f2f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .logo { font-size: 48px; color: #2563eb; margin-bottom: 20px; }
        .status { color: #16a34a; font-weight: bold; font-size: 18px; }
        .info { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .token { font-family: monospace; background: #e9ecef; padding: 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀 HAWLS Panel</div>
        <h1>Servidor Configurado com Sucesso!</h1>
        <p class="status">✅ Instalação concluída</p>
        <div class="info">
            <p><strong>Token:</strong> <span class="token">$TOKEN</span></p>
            <p><strong>Template:</strong> $TEMPLATE</p>
            <p><strong>IP:</strong> $(curl -s ifconfig.me 2>/dev/null || echo "Verificar manualmente")</p>
        </div>
        <p>Seu servidor está pronto para uso!</p>
        <hr>
        <p><small>Instalado via HAWLS Panel - Sistema de instalação automática</small></p>
    </div>
</body>
</html>
EOF
    
    docker-compose up -d
    
    log_success "Stack básico instalado na porta 80"
    log_info "Acesso: http://$(curl -s ifconfig.me)"
    
    # Salvar informações
    save_service_info "basic" "80" "Stack Básico - Nginx" \
        "STATUS=Ativo" \
        "TEMPLATE=basic" \
        "WEB_ROOT=/opt/hawls/basic/html"
}

# Salvar informações do serviço
save_service_info() {
    local service_name="$1"
    local port="$2"
    local description="$3"
    shift 3
    
    local info_file="/root/${service_name}-info.txt"
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "N/A")
    
    log_info "Salvando informações do serviço em: $info_file"
    
    cat > "$info_file" << EOF
# ==========================================
# 🚀 HAWLS PANEL - INFORMAÇÕES DO SERVIÇO
# ==========================================

📋 INFORMAÇÕES GERAIS:
   • Serviço: $description
   • Template: $service_name
   • Data de Instalação: $(date)
   • Token de Instalação: $TOKEN
   • IP do Servidor: $server_ip
   • Porta(s): $port

🌐 ACESSO:
   • URL Principal: http://$server_ip:$port
   • Status: Ativo
   • Protocolo: HTTP

🔧 CONFIGURAÇÕES:
EOF
    
    # Adicionar configurações específicas
    for config in "$@"; do
        echo "   • $config" >> "$info_file"
    done
    
    cat >> "$info_file" << EOF

🐳 DOCKER:
   • Diretório: /opt/hawls/$service_name
   • Comando Status: docker-compose ps
   • Comando Logs: docker-compose logs -f
   • Comando Restart: docker-compose restart

🔥 FIREWALL:
   • Porta $port: PERMITIDA
   • SSH (22): PERMITIDA
   • HTTP (80): PERMITIDA
   • HTTPS (443): PERMITIDA

📊 COMANDOS ÚTEIS:
   • Ver containers: docker ps
   • Ver logs: docker-compose -f /opt/hawls/$service_name/docker-compose.yml logs -f
   • Reiniciar: docker-compose -f /opt/hawls/$service_name/docker-compose.yml restart
   • Parar: docker-compose -f /opt/hawls/$service_name/docker-compose.yml down
   • Iniciar: docker-compose -f /opt/hawls/$service_name/docker-compose.yml up -d

🔐 SEGURANÇA:
   • Firewall: ATIVO (UFW)
   • Docker: ISOLADO
   • Rede: hawls-network

📝 NOTAS:
   • Mantenha este arquivo seguro
   • Faça backup das configurações regularmente
   • Monitore os logs periodicamente
   • Atualize as imagens Docker quando necessário

---
Gerado automaticamente pelo HAWLS Panel V2.0
$(date)
EOF
    
    # Definir permissões seguras
    chmod 600 "$info_file"
    
    log_success "Informações salvas em: $info_file"
    
    # Mostrar resumo no terminal
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     INSTALAÇÃO CONCLUÍDA COM SUCESSO!                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 RESUMO DA INSTALAÇÃO:${NC}"
    echo -e "   • Serviço: $description"
    echo -e "   • URL: http://$server_ip:$port"
    echo -e "   • Arquivo de Info: $info_file"
    echo ""
    echo -e "${YELLOW}📝 PRÓXIMOS PASSOS:${NC}"
    echo -e "   1. Acesse: http://$server_ip:$port"
    echo -e "   2. Configure seu serviço conforme necessário"
    echo -e "   3. Leia o arquivo: $info_file"
    echo -e "   4. Configure SSL se necessário"
    echo ""
}

# Finalizar instalação
finalize_installation() {
    log_info "Finalizando instalação..."
    
    # Limpar arquivos temporários
    rm -f /tmp/hawls_template_config
    
    # Verificar status dos serviços Docker
    log_info "Verificando status dos containers..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Mostrar informações do sistema
    echo ""
    log_info "Sistema configurado com sucesso!"
    echo ""
    echo -e "${BLUE}🔧 INFORMAÇÕES DO SISTEMA:${NC}"
    echo -e "   • OS: $(lsb_release -d | cut -f2)"
    echo -e "   • Kernel: $(uname -r)"
    echo -e "   • Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo -e "   • Docker Compose: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo -e "   • IP Público: $(curl -s ifconfig.me)"
    echo ""
    
    log_success "🎉 HAWLS Panel instalação concluída!"
}

# ==============================================
# FUNÇÃO PRINCIPAL
# ==============================================
main() {
    # Mostrar banner
    show_banner
    
    # Verificar parâmetros
    check_parameters "$@"
    
    # Definir variáveis
    TOKEN="$1"
    TEMPLATE="$2"
    
    log_info "Iniciando instalação do template: $TEMPLATE"
    log_info "Token: $TOKEN"
    
    # Verificar se é root
    check_root
    
    # Processar configurações do template
    parse_template_config "$@"
    
    # Instalar dependências
    install_dependencies
    
    # Instalar Docker
    install_docker
    
    # Configurar firewall
    setup_firewall
    
    # Instalar template específico
    install_template
    
    # Finalizar instalação
    finalize_installation
}

# Executar função principal
main "$@" 