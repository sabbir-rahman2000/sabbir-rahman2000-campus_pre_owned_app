# Campus Pre-owned - Backend Development Guide

## API Endpoints Required

### Authentication
```
POST /auth/login
POST /auth/register
POST /auth/verify-email
POST /auth/forgot-password
POST /auth/reset-password
GET  /auth/refresh-token
```

### User Management
```
GET    /users/profile
PUT    /users/profile
POST   /users/upload-avatar
DELETE /users/account
```

### Products
```
GET    /products                 # List with filters
GET    /products/{id}           # Product details
POST   /products                # Create listing
PUT    /products/{id}           # Update listing
DELETE /products/{id}           # Delete listing
POST   /products/{id}/images    # Upload images
GET    /products/categories     # Get categories
GET    /products/search         # Search products
```

### Wishlist
```
GET    /users/wishlist
POST   /users/wishlist/{productId}
DELETE /users/wishlist/{productId}
```

### Messages
```
GET    /messages/conversations
GET    /messages/conversations/{id}
POST   /messages/conversations
POST   /messages/conversations/{id}/messages
PUT    /messages/{id}/read
```

### Orders
```
GET    /orders/history
POST   /orders
PUT    /orders/{id}/status
GET    /orders/{id}
```

### Reviews
```
GET    /products/{id}/reviews
POST   /products/{id}/reviews
GET    /users/{id}/reviews
```

### Notifications
```
GET    /notifications
PUT    /notifications/{id}/read
POST   /notifications/mark-all-read
```

## Database Schema

### Users Table
```sql
users (
  id, email, password_hash, first_name, last_name,
  phone, avatar_url, is_verified, created_at, updated_at
)
```

### Products Table
```sql
products (
  id, seller_id, title, description, price, category_id,
  condition, images[], is_available, created_at, updated_at
)
```

### Categories Table
```sql
categories (
  id, name, icon, parent_id
)
```

### Messages Table
```sql
conversations (id, buyer_id, seller_id, product_id, created_at)
messages (id, conversation_id, sender_id, content, created_at, is_read)
```

### Orders Table
```sql
orders (
  id, buyer_id, seller_id, product_id, status,
  total_amount, created_at, updated_at
)
```

### Reviews Table
```sql
reviews (
  id, reviewer_id, reviewee_id, product_id, order_id,
  rating, comment, created_at
)
```

### Wishlist Table
```sql
wishlist (
  user_id, product_id, created_at
)
```

## Required Integrations

### Email Service
- University email verification (@zzu.edu.cn)
- Password reset emails
- Order confirmations

### File Storage
- Product image uploads
- User avatar uploads
- Image resizing/optimization

### Push Notifications
- New message alerts
- Order status updates
- Wishlist item availability

### Real-time Features
- WebSocket for messaging
- Live product updates
- Online status indicators

## Authentication Flow
1. Email validation (must be @zzu.edu.cn)
2. Send verification email
3. JWT token generation
4. Refresh token mechanism

## Image Upload Requirements
- Max file size: 5MB per image
- Formats: JPG, PNG, WebP
- Auto-resize to multiple sizes
- CDN integration recommended

## Search Implementation
- Full-text search on title/description
- Category filtering
- Price range filtering
- Condition filtering
- Sort by: price, date, relevance

## Security Requirements
- JWT authentication
- Rate limiting on APIs
- Input validation/sanitization
- University email domain verification
- HTTPS only

## Mock Data Migration
Current mock data in `lib/utils/models.dart`:
- 6 sample products
- 5 message conversations
- User profiles
- Categories list

## WebSocket Events
```
message_sent
message_received
user_online
user_offline
product_updated
order_status_changed
```

## Error Response Format
```json
{
  "error": true,
  "message": "Error description",
  "code": "ERROR_CODE",
  "details": {}
}
```

## Success Response Format
```json
{
  "success": true,
  "data": {},
  "message": "Optional success message"
}
```