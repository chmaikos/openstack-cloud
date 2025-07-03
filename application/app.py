#!/usr/bin/env python3
"""
FastAPI Web Application for OpenStack Cloud Assignment
Εργασία Εξαμήνου - Διαχείριση Υπολογιστικού Νέφους
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
import psycopg2.extras
import os
import psutil
from datetime import datetime
import uvicorn

app = FastAPI(
    title="Cloud Application",
    description="OpenStack Cloud Assignment - Two-tier Application",
    version="1.0.0"
)

# Import configuration
from config import DB_CONFIG, get_db_connection

# Pydantic models
class User(BaseModel):
    id: Optional[int] = None
    username: str
    email: str
    created_at: Optional[str] = None

class Post(BaseModel):
    id: Optional[int] = None
    user_id: int
    title: str
    content: str
    created_at: Optional[str] = None

class PostCreate(BaseModel):
    user_id: int
    title: str
    content: str



def get_system_stats():
    """Get system statistics"""
    return {
        'timestamp': datetime.now().isoformat(),
        'cpu_percent': psutil.cpu_percent(interval=1),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_percent': psutil.disk_usage('/').percent,
        'network_io': psutil.net_io_counters()._asdict()
    }

@app.get("/", response_class=HTMLResponse)
async def root():
    """Home page"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Cloud Application - OpenStack Assignment</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
        <style>
            .hero { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        </style>
    </head>
    <body>
        <nav class="navbar navbar-dark bg-dark">
            <div class="container">
                <span class="navbar-brand">☁️ Cloud Application</span>
                <div class="navbar-nav">
                    <a class="nav-link" href="/docs">API Docs</a>
                    <a class="nav-link" href="/health">Health</a>
                </div>
            </div>
        </nav>
        
        <div class="hero py-5">
            <div class="container text-center">
                <h1>OpenStack Cloud Application</h1>
                <p class="lead">Εργασία Εξαμήνου - Διαχείριση Υπολογιστικού Νέφους</p>
                <p>FastAPI + PostgreSQL Two-tier Architecture</p>
            </div>
        </div>
        
        <div class="container my-5">
            <div class="row">
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body text-center">
                            <h5>🌐 FastAPI Server</h5>
                            <p>Modern web framework with automatic API documentation</p>
                            <a href="/docs" class="btn btn-primary">View API Docs</a>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body text-center">
                            <h5>💾 PostgreSQL Database</h5>
                            <p>Reliable database with automated setup and monitoring</p>
                            <a href="/api/users" class="btn btn-success">View Users</a>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body text-center">
                            <h5>📊 System Monitoring</h5>
                            <p>Real-time system statistics and health monitoring</p>
                            <a href="/health" class="btn btn-info">View Health</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <footer class="bg-dark text-white text-center py-3">
            <p>&copy; 2024 OpenStack Cloud Assignment</p>
        </footer>
    </body>
    </html>
    """

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    db_status = "OK" if get_db_connection() else "ERROR"
    return {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'database': db_status,
        'system': get_system_stats()
    }

@app.get("/api/users", response_model=List[User])
async def get_users():
    """Get all users"""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute('SELECT * FROM users ORDER BY created_at DESC')
        users = cur.fetchall()
        cur.close()
        conn.close()
        return [User(**dict(user)) for user in users]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/posts", response_model=List[dict])
async def get_posts():
    """Get all posts with user information"""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute('''
            SELECT p.*, u.username 
            FROM posts p 
            JOIN users u ON p.user_id = u.id 
            ORDER BY p.created_at DESC
        ''')
        posts = cur.fetchall()
        cur.close()
        conn.close()
        return [dict(post) for post in posts]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/posts", response_model=dict)
async def create_post(post: PostCreate):
    """Create a new post"""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO posts (user_id, title, content) VALUES (%s, %s, %s) RETURNING id',
            (post.user_id, post.title, post.content)
        )
        post_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return {'id': post_id, 'message': 'Post created successfully'}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/stats")
async def get_stats():
    """Get system and application statistics"""
    conn = get_db_connection()
    db_stats = {}
    
    if conn:
        try:
            cur = conn.cursor()
            cur.execute('SELECT COUNT(*) FROM users')
            db_stats['users_count'] = cur.fetchone()[0]
            cur.execute('SELECT COUNT(*) FROM posts')
            db_stats['posts_count'] = cur.fetchone()[0]
            cur.close()
            conn.close()
        except:
            db_stats = {'error': 'Database query failed'}
    
    return {
        'system': get_system_stats(),
        'database': db_stats,
        'application': {
            'name': 'Cloud Application',
            'version': '1.0.0',
            'description': 'OpenStack Cloud Assignment - Two-tier Application',
            'framework': 'FastAPI',
            'database': 'PostgreSQL'
        }
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 