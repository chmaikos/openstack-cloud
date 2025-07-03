import os
import psycopg2

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'db-server'),
    'database': os.getenv('DB_NAME', 'cloudapp'),
    'user': os.getenv('DB_USER', 'cloudapp'),
    'password': os.getenv('DB_PASSWORD', 'cloudapp123'),
    'port': os.getenv('DB_PORT', '5432')
}

# Application configuration
APP_HOST = os.getenv('APP_HOST', '0.0.0.0')
APP_PORT = int(os.getenv('APP_PORT', 8000))

# Security
SECRET_KEY = os.getenv('SECRET_KEY', 'your-secret-key-change-in-production')

# Logging
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

def get_db_connection():
    """Create database connection using configuration"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

def get_database_url():
    """Get database URL for SQLAlchemy or other ORM"""
    return f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}" 