#!/usr/bin/env python3
"""
Database initialization script for Cloud Application
Εργασία Εξαμήνου - Διαχείριση Υπολογιστικού Νέφους
"""

import psycopg2
import os

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'cloudapp',
    'user': 'cloudapp',
    'password': 'cloudapp123',
    'port': '5432'
}

def init_database():
    """Initialize database with tables and sample data"""
    try:
        # Connect to database
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        
        print("Connected to PostgreSQL database")
        
        # Create tables
        print("Creating tables...")
        
        # Users table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Posts table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS posts (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id),
                title VARCHAR(200) NOT NULL,
                content TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        print("Tables created successfully")
        
        # Insert sample data
        print("Inserting sample data...")
        
        # Check if users already exist
        cur.execute("SELECT COUNT(*) FROM users")
        user_count = cur.fetchone()[0]
        
        if user_count == 0:
            # Insert sample users
            cur.execute("""
                INSERT INTO users (username, email) VALUES 
                    ('admin', 'admin@cloudapp.com'),
                    ('user1', 'user1@cloudapp.com'),
                    ('user2', 'user2@cloudapp.com')
            """)
            print("Sample users inserted")
        
        # Check if posts already exist
        cur.execute("SELECT COUNT(*) FROM posts")
        post_count = cur.fetchone()[0]
        
        if post_count == 0:
            # Insert sample posts
            cur.execute("""
                INSERT INTO posts (user_id, title, content) VALUES 
                    (1, 'Welcome to Cloud Application', 'This is the first post in our cloud application. Welcome to the OpenStack assignment!'),
                    (2, 'Hello from User1', 'Hello everyone! This is a test post from user1.'),
                    (3, 'Cloud Computing is Amazing', 'Learning about cloud computing and OpenStack has been an amazing experience.'),
                    (1, 'System Status', 'The application is running smoothly on our two-tier architecture.')
            """)
            print("Sample posts inserted")
        
        # Commit changes
        conn.commit()
        
        # Display statistics
        cur.execute("SELECT COUNT(*) FROM users")
        users_count = cur.fetchone()[0]
        
        cur.execute("SELECT COUNT(*) FROM posts")
        posts_count = cur.fetchone()[0]
        
        print(f"\nDatabase Statistics:")
        print(f"- Users: {users_count}")
        print(f"- Posts: {posts_count}")
        
        cur.close()
        conn.close()
        
        print("\nDatabase initialization completed successfully!")
        
    except Exception as e:
        print(f"Error initializing database: {e}")
        return False
    
    return True

if __name__ == "__main__":
    init_database() 