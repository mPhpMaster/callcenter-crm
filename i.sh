#!/bin/bash

# ============================================
# CALL CENTER CRM - COMPLETE SETUP GUIDE
# ============================================

# 1. CREATE NEW LARAVEL PROJECT
composer create-project laravel/laravel callcenter-crm
cd callcenter-crm

# 2. INSTALL REQUIRED PACKAGES
composer require maatwebsite/excel

# 3. CONFIGURE DATABASE
# Edit .env file with your database credentials:
# DB_CONNECTION=mysql
# DB_HOST=127.0.0.1
# DB_PORT=3306
# DB_DATABASE=callcenter_crm
# DB_USERNAME=root
# DB_PASSWORD=your_password

# Create database (if using MySQL)
mysql -u root -p -e "CREATE DATABASE callcenter_crm;"

# 4. CREATE MIGRATIONS
php artisan make:migration create_leads_table
php artisan make:migration create_lead_history_table

# 5. CREATE MODELS
php artisan make:model Lead
php artisan make:model LeadHistory

# 6. CREATE CONTROLLER
php artisan make:controller LeadController

# 7. CREATE IMPORT CLASS
php artisan make:import LeadsImport --model=Lead

# 8. RUN MIGRATIONS
php artisan migrate

# 9. INSTALL FRONTEND DEPENDENCIES
npm install

# Install Vue 3 and required packages (use specific versions)
npm install vue@latest @vitejs/plugin-vue
npm install axios

# 10. CONFIGURE VITE FOR VUE
# You'll need to update vite.config.js (see below)

# 11. BUILD FRONTEND ASSETS
npm run dev

# 12. START LARAVEL SERVER (in a new terminal)
php artisan serve

# Your app will be available at: http://localhost:8000

# ============================================
# ADDITIONAL CONFIGURATION FILES NEEDED
# ============================================

# FILE: vite.config.js
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        vue({
            template: {
                transformAssetUrls: {
                    base: null,
                    includeAbsolute: false,
                },
            },
        }),
    ],
    resolve: {
        alias: {
            vue: 'vue/dist/vue.esm-bundler.js',
        },
    },
});
EOF

# FILE: resources/js/app.js
cat > resources/js/app.js << 'EOF'
import './bootstrap';
import { createApp } from 'vue';
import CallCenterCRM from './components/CallCenterCRM.vue';

const app = createApp({});
app.component('call-center-crm', CallCenterCRM);
app.mount('#app');
EOF

# FILE: resources/views/welcome.blade.php (replace content)
cat > resources/views/welcome.blade.php << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Call Center CRM</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
    <div id="app">
        <call-center-crm></call-center-crm>
    </div>
</body>
</html>
EOF

# FILE: resources/js/bootstrap.js (update axios config)
cat > resources/js/bootstrap.js << 'EOF'
import axios from 'axios';
window.axios = axios;

window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
window.axios.defaults.baseURL = 'http://localhost:8000';

// Add CSRF token
let token = document.head.querySelector('meta[name="csrf-token"]');
if (token) {
    window.axios.defaults.headers.common['X-CSRF-TOKEN'] = token.content;
}
EOF

# ============================================
# CREATE DIRECTORY STRUCTURE
# ============================================

# Create component directory
mkdir -p resources/js/components

# Create imports directory
mkdir -p app/Imports

# ============================================
# PERMISSIONS (for Linux/Mac)
# ============================================

# Set proper permissions
chmod -R 775 storage bootstrap/cache
chown -R $USER:www-data storage bootstrap/cache

# ============================================
# OPTIONAL: SEED SAMPLE DATA
# ============================================

# Create seeder
php artisan make:seeder LeadSeeder

# Run seeder
php artisan db:seed --class=LeadSeeder

# ============================================
# TESTING THE API (Optional)
# ============================================

# Test leads endpoint
curl http://localhost:8000/api/leads

# Test clients endpoint
curl http://localhost:8000/api/leads/clients

# ============================================
# PRODUCTION BUILD
# ============================================

# When ready for production
npm run build
php artisan config:cache
php artisan route:cache
php artisan view:cache

# ============================================
# TROUBLESHOOTING COMMANDS
# ============================================

# Clear all caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Reset database (WARNING: deletes all data)
php artisan migrate:fresh

# Check routes
php artisan route:list

# Check if migrations ran
php artisan migrate:status

# Generate application key (if needed)
php artisan key:generate

# ============================================
# SAMPLE EXCEL FILE FORMAT
# ============================================
# Your Excel file should have these columns:
# - name
# - email
# - phone
# - company
# - notes

# Example CSV format:
cat > sample_leads.csv << 'EOF'
name,email,phone,company,notes
John Doe,john@example.com,555-0101,Acme Corp,Interested in product demo
Jane Smith,jane@example.com,555-0102,Tech Inc,Follow up next week
Bob Johnson,bob@example.com,555-0103,StartupXYZ,Hot lead - ready to buy
EOF

echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo "1. Make sure your database is configured in .env"
echo "2. Run: php artisan serve"
echo "3. In another terminal run: npm run dev"
echo "4. Open: http://localhost:8000"
echo "======================================"