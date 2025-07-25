#!/bin/bash

# Service Management Script for FFmpeg Translation Middleware

APP_NAME="translate-glue"

show_usage() {
    echo "Usage: $0 {start|stop|restart|status|logs|config|health|uninstall}"
    echo ""
    echo "Commands:"
    echo "  start     - Start the service"
    echo "  stop      - Stop the service"
    echo "  restart   - Restart the service"
    echo "  status    - Show service status"
    echo "  logs      - Show live logs"
    echo "  config    - Edit configuration"
    echo "  health    - Test health endpoint"
    echo "  uninstall - Remove the service completely"
}

check_service_exists() {
    if ! systemctl list-unit-files | grep -q "$APP_NAME.service"; then
        echo "Error: Service $APP_NAME is not installed"
        echo "Run the deployment script first: sudo ./deploy-ubuntu.sh"
        exit 1
    fi
}

case "$1" in
    start)
        check_service_exists
        echo "Starting $APP_NAME..."
        systemctl start $APP_NAME
        echo "Service started. Check status with: $0 status"
        ;;
    stop)
        check_service_exists
        echo "Stopping $APP_NAME..."
        systemctl stop $APP_NAME
        echo "Service stopped."
        ;;
    restart)
        check_service_exists
        echo "Restarting $APP_NAME..."
        systemctl restart $APP_NAME
        echo "Service restarted. Check status with: $0 status"
        ;;
    status)
        check_service_exists
        systemctl status $APP_NAME --no-pager
        ;;
    logs)
        check_service_exists
        echo "Showing live logs (Press Ctrl+C to exit)..."
        journalctl -u $APP_NAME -f
        ;;
    config)
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root to edit configuration: sudo $0 config"
            exit 1
        fi
        echo "Opening configuration file..."
        ${EDITOR:-nano} /etc/default/$APP_NAME
        echo "Configuration updated. Restart service to apply changes: $0 restart"
        ;;
    health)
        echo "Testing health endpoint..."
        if curl -f -s http://localhost:3001/health | jq . 2>/dev/null; then
            echo "✅ Service is healthy!"
        elif curl -f -s http://localhost:3001/health 2>/dev/null; then
            echo "✅ Service is responding (install jq for formatted output)"
        else
            echo "❌ Service is not responding"
            echo "Check service status: $0 status"
            exit 1
        fi
        ;;
    uninstall)
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root to uninstall: sudo $0 uninstall"
            exit 1
        fi
        
        echo "This will completely remove $APP_NAME from your system."
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Uninstalling $APP_NAME..."
            
            # Stop and disable service
            systemctl stop $APP_NAME 2>/dev/null || true
            systemctl disable $APP_NAME 2>/dev/null || true
            
            # Remove service files
            rm -f /etc/systemd/system/$APP_NAME.service
            rm -f /etc/default/$APP_NAME
            rm -f /etc/logrotate.d/$APP_NAME
            
            # Remove application directory
            rm -rf /opt/$APP_NAME
            
            # Remove logs
            rm -rf /var/log/$APP_NAME
            
            # Remove service user
            userdel translate-glue 2>/dev/null || true
            
            # Reload systemd
            systemctl daemon-reload
            
            echo "✅ $APP_NAME has been completely removed."
        else
            echo "Uninstall cancelled."
        fi
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
