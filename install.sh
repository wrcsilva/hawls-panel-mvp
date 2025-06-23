#!/bin/bash

# =====================================================
# HAWLS Panel - Script de Instalação Automática
# Instalação completa para VPS limpa
# =====================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
TOKEN="${1:-}"
TEMPLATE="${2:-basic}"
HAWLS_API_URL="${HAWLS_API_URL:-https://api.hawls.com.br}"

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
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           HAWLS Panel Installer      ║${NC}"
    echo -e "${BLUE}║       Instalação Automática VPS     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
}

# Verificar se é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script deve ser executado como root"
        log_info "Execute: sudo su - && curl -sSL https://raw.githubusercontent.com/wrcsilva/hawls-panel-mvp/master/install.sh | bash -s -- \"$TOKEN\" \"$TEMPLATE\""
        exit 1
    fi
}

# Verificar token
check_token() {
    if [[ -z "$TOKEN" ]]; then
        log_error "Token de instalação não fornecido"
        log_info "Uso: curl -sSL https://raw.githubusercontent.com/wrcsilva/hawls-panel-mvp/master/install.sh | bash -s -- TOKEN TEMPLATE"
        exit 1
    fi
    
    log_info "Token: $TOKEN"
    log_info "Template: $TEMPLATE"
}

# Verificar sistema operacional
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Sistema operacional não suportado"
        exit 1
    fi
    
    log_info "Sistema: $OS $VER"
    
    # Verificar se é Ubuntu/Debian
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
        log_warning "Sistema não testado. Continuando..."
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
        vim
    
    log_success "Dependências básicas instaladas"
}

# Atualizar sistema
update_system() {
    log_info "Atualizando sistema..."
    apt update -y
    apt upgrade -y
    log_success "Sistema atualizado"
}

# Instalar Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker já instalado"
        return
    fi
    
    log_info "Instalando Docker..."
    
    # Remover versões antigas
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Adicionar chave GPG oficial do Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Adicionar repositório
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker Engine
    apt update -y
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Iniciar e habilitar Docker
    systemctl start docker
    systemctl enable docker
    
    # Adicionar usuário ao grupo docker (se não for root)
    if [[ $EUID -ne 0 ]] && [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker $SUDO_USER
        log_info "Usuário $SUDO_USER adicionado ao grupo docker"
    fi
    
    log_success "Docker instalado com sucesso"
}

# Instalar Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose já instalado"
        return
    fi
    
    log_info "Instalando Docker Compose..."
    
    # Baixar Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Dar permissão de execução
    chmod +x /usr/local/bin/docker-compose
    
    # Criar link simbólico
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose instalado"
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
    
    mkdir -p /opt/hawls/evolution-api
    cd /opt/hawls/evolution-api
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  evolution-api:
    image: atendai/evolution-api:v2.2.3
    container_name: evolution-api
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - AUTHENTICATION_API_KEY=hawls-key-change-me
      - SERVER_URL=https://api.exemplo.com
      - DATABASE_ENABLED=false
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    networks:
      - hawls-network

volumes:
  evolution_instances:
  evolution_store:

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
}

# Instalar N8N
install_n8n() {
    log_info "Configurando N8N..."
    
    mkdir -p /opt/hawls/n8n
    cd /opt/hawls/n8n
    
    cat > docker-compose.yml << 'EOF'
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
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=hawls-n8n-password
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - hawls-network

volumes:
  n8n_data:

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
        log_info "Usuário: admin | Senha: hawls-n8n-password"
    else
        log_warning "N8N pode estar ainda inicializando"
    fi
}

# Instalar Typebot
install_typebot() {
    log_info "Configurando Typebot..."
    
    mkdir -p /opt/hawls/typebot
    cd /opt/hawls/typebot
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  typebot:
    image: baptistearno/typebot-builder:latest
    container_name: typebot
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NEXTAUTH_URL=https://typebot.exemplo.com
      - DATABASE_URL=file:./db.sqlite
    volumes:
      - typebot_data:/app/data
    networks:
      - hawls-network

volumes:
  typebot_data:

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
        log_success "Typebot instalado com sucesso na porta 3000"
        log_info "Acesso: http://$(curl -s ifconfig.me):3000"
    else
        log_warning "Typebot pode estar ainda inicializando"
    fi
}

# Instalar stack básico
install_basic_stack() {
    log_info "Configurando stack básico..."
    
    mkdir -p /opt/hawls/basic
    cd /opt/hawls/basic
    
    cat > docker-compose.yml << 'EOF'
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
}

# Finalizar instalação
finish_installation() {
    log_success "Instalação concluída com sucesso!"
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            INSTALAÇÃO CONCLUÍDA      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    log_info "Template instalado: $TEMPLATE"
    log_info "Token utilizado: $TOKEN"
    log_info "IP do servidor: $(curl -s ifconfig.me 2>/dev/null || echo "Verificar manualmente")"
    echo ""
    log_info "Para gerenciar os containers:"
    log_info "  docker ps                    # Listar containers"
    log_info "  docker-compose logs -f       # Ver logs"
    log_info "  docker-compose restart       # Reiniciar"
    echo ""
}

# Função principal
main() {
    show_banner
    check_root
    check_token
    check_os
    install_dependencies
    update_system
    install_docker
    install_docker_compose
    setup_firewall
    install_template
    finish_installation
}

# Executar função principal
main "$@" 