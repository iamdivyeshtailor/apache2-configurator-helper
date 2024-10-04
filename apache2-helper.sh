#!/bin/bash

# Function to check if Apache2 is installed
check_apache_installed() {
    if ! command -v apache2 &> /dev/null; then
        echo "Apache2 is not installed on this system."
        read -p "Do you want to install Apache2? (y/n): " install_apache
        if [ "$install_apache" == "y" ]; then
            install_apache
        else
            echo "Apache2 installation skipped. Exiting..."
            exit 1
        fi
    else
        echo "Apache2 is already installed."
    fi
}

# Function to install Apache2
install_apache() {
    echo "Installing Apache2..."
    sudo apt update
    sudo apt install apache2 -y
    sudo a2enmod proxy
    sudo a2enmod proxy_http
    sudo a2enmod rewrite
    sudo a2enmod ssl
    sudo systemctl restart apache2
}

# Function to check if Certbot is installed
check_certbot_installed() {
    if ! command -v certbot &> /dev/null; then
        echo "Certbot is not installed on this system."
        read -p "Do you want to install Certbot? (y/n): " install_certbot
        if [ "$install_certbot" == "y" ]; then
            install_certbot
        else
            echo "Certbot installation skipped. SSL will not be configured."
            return 1
        fi
    else
        echo "Certbot is already installed."
    fi
    return 0
}

# Function to install Certbot
install_certbot() {
    echo "Installing Certbot..."
    sudo apt update
    sudo apt install certbot python3-certbot-apache -y
}

# Step 1: Check if Apache2 is installed
check_apache_installed

# Step 2: Get the server IP and display it
server_ip=$(hostname -I | awk '{print $1}')
echo "Your server's IP is: $server_ip"
echo "Please point your domain to this IP."

# Step 3: Ask for the domain name
read -p "Enter your domain name: " domain_name

# Step 4: Ask for the port number or proxy
read -p "Enter the port number or proxy on which your application is running (e.g., 3000): " app_port

# Step 5: Create the Apache virtual host configuration file
create_apache_config() {
    local domain_name=$1
    local port=$2

    # Apache virtual host configuration content
    cat <<EOL > /etc/apache2/sites-available/$domain_name.conf
<VirtualHost *:80>
    ServerName $domain_name
    DocumentRoot /var/www/html

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:$port/
    ProxyPassReverse / http://127.0.0.1:$port/

    ErrorLog \${APACHE_LOG_DIR}/$domain_name-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain_name-access.log combined
</VirtualHost>
EOL

    echo "Apache configuration created for domain: $domain_name"
}

# Step 6: Enable the new Apache configuration and reload Apache
create_apache_config "$domain_name" "$app_port"
sudo a2ensite $domain_name.conf
sudo systemctl reload apache2

# Step 7: Test Apache configuration
echo "Testing Apache configuration..."
apachectl configtest

if [ $? -eq 0 ]; then
    echo "Apache configuration is valid."
else
    echo "There is an error in the Apache configuration. Please fix the issues and try again."
    exit 1
fi

# Step 8: Check if Certbot is installed and offer to install SSL certificate
check_certbot_installed
if [ $? -eq 0 ]; then
    echo "Assigning SSL certificate using Certbot for domain: $domain_name"
    sudo certbot --apache -d $domain_name
    if [ $? -eq 0 ]; then
        echo "SSL certificate successfully assigned to $domain_name."
    else
        echo "Failed to assign SSL certificate. Please try manually."
    fi
fi
