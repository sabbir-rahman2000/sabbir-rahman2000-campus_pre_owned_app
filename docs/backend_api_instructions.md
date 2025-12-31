# Campus Pre-owned Backend API – Development Instructions

These instructions define the backend API to make the Flutter app dynamic. It maps UI flows to REST endpoints, data models, validation rules, and security. Implement with any modern stack (e.g., Node/NestJS/Express, Python/FastAPI, Go), following JSON over HTTP and JWT auth.

## Base Conventions
- Base URL: `https://api.example.com/v1`
- Content type: `application/json`
- Auth: JWT `Authorization: Bearer <access_token>`
- Pagination: `page`, `pageSize` (default 1/20)
- Sorting: `sort` (e.g., `createdAt:desc`)
- Dates: ISO 8601 strings
- IDs: UUIDs server-side; client uses `int` for demo data but backend should use strings
- Errors: JSON with standardized format below

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Password must be at least 6 characters",
    "details": [{"field": "password", "issue": "minLength"}]
  }
}
```

## Authentication & Accounts
Screens: `Login`, `Sign Up`, `Admin Login`, `Forgot Password`.

- POST `/auth/signup`
  - Body: `{ name, email, studentId, password }`
  - Validation: email must end with `@zzu.edu.cn`; password ≥ 6; name ≥ 2; studentId ≥ 6.
  - 201: `{ user, accessToken, refreshToken }`
- POST `/auth/login`
  - Body: `{ email, password }`
  - 200: `{ user, accessToken, refreshToken }`
- POST `/auth/admin/login`
  - Body: `{ username, password }`
  - 200: `{ admin, accessToken }`
- POST `/auth/forgot-password`
  - Body: `{ email }`
  - 200: `{ sent: true }` (email with link)
- POST `/auth/refresh`
  - Body: `{ refreshToken }`
  - 200: `{ accessToken }`
- POST `/auth/logout`
  - Body: `{ refreshToken }`
  - 204: empty

User model
```json
{
  "id": "uuid",
  "name": "Student User",
  "email": "student@zzu.edu.cn",
  "studentId": "202312345",
  "rating": 4.9,
  "avatarUrl": null,
  "roles": ["user"]
}
```

## Profile
Screens: `Profile`, Stats, Settings.

- GET `/me`
  - 200: `User`
- PATCH `/me`
  - Body: partial `User` updates (e.g., `name`, `avatarUrl`)
  - 200: `User`
- GET `/me/stats`
  - 200: `{ itemsSold, itemsBought, rating }`

## Categories
Used in `Home` and `Sell`.

- GET `/categories`
  - 200: `[{ id, label, icon, color }]`

Category model
```json
{ "id": "uuid", "label": "Electronics", "icon": "laptop", "color": "#87CEEB" }
```

## Products & Listings
Screens: `Home`, `Search`, `Product Detail`, `Sell`, `My Listings`.

- GET `/products`
  - Query: `search`, `categoryId`, `sellerId`, `minPrice`, `maxPrice`, `page`, `pageSize`, `sort`
  - 200: `{ items: [Product], page, pageSize, total }`
- GET `/products/{productId}`
  - 200: `Product`
- POST `/products`
  - Auth: user
  - Body: `{ title, description, price, categoryId, imageUrls[] }`
  - 201: `Product`
- PATCH `/products/{productId}`
  - Auth: owner or admin
  - Body: partial update
  - 200: `Product`
- DELETE `/products/{productId}`
  - Auth: owner or admin
  - 204: empty
- GET `/users/{userId}/products`
  - 200: `[Product]` (for `My Listings`)

Product model
```json
{
  "id": "uuid",
  "title": "Dell Laptop - i5, 8GB RAM",
  "description": "...",
  "price": 2350.0,
  "category": {"id": "uuid", "label": "Electronics"},
  "imageUrls": ["https://..."],
  "seller": {"id": "uuid", "name": "Mike R."},
  "rating": 4.8,
  "status": "available", // available | sold | archived
  "location": "Zhengzhou University",
  "createdAt": "2025-12-01T12:34:56Z"
}
```

### Media Uploads
- POST `/uploads`
  - Multipart: `files[]`
  - 201: `{ urls: ["https://.../file1.jpg", ...] }`

## Search
`SearchScreen` uses client-side search now; move to server:
- GET `/search`
  - Query: `q`, `categoryId`, `page`, `pageSize`
  - 200: `{ items: [Product], total }`

## Wishlist
Screens: `Wishlist`, `ProductCard` toggle.

- GET `/me/wishlist`
  - 200: `[Product]`
- POST `/me/wishlist/{productId}`
  - 201: `{ added: true }`
- DELETE `/me/wishlist/{productId}`
  - 204: empty

## Messaging & Conversations
Screens: `Messages`, `Product Detail` actions.

- GET `/conversations`
  - 200: `[Conversation]`
- POST `/conversations`
  - Body: `{ participantId, productId? }`
  - 201: `Conversation`
- GET `/conversations/{id}/messages`
  - 200: `[Message]`
- POST `/conversations/{id}/messages`
  - Body: `{ text }`
  - 201: `Message`

Conversation
```json
{
  "id": "uuid",
  "participants": [{"id": "uuid", "name": "You"}, {"id": "uuid", "name": "Seller"}],
  "product": {"id": "uuid", "title": "..."},
  "lastMessage": {"id": "uuid", "text": "Is it available?", "createdAt": "..."},
  "unreadCount": 1,
  "updatedAt": "2025-12-20T10:00:00Z"
}
```
Message
```json
{ "id": "uuid", "senderId": "uuid", "text": "Hello", "createdAt": "..." }
```

## Notifications
Screens: `Notifications`.

- GET `/notifications`
  - Query: `page`, `pageSize`, `unreadOnly`
  - 200: `{ items: [Notification], total }`
- PATCH `/notifications/{id}/read`
  - Body: `{ read: true }`
  - 200: `Notification`

Notification
```json
{
  "id": "uuid",
  "type": "message", // message | order | system
  "title": "New message from seller",
  "body": "Someone is interested in your item",
  "read": false,
  "createdAt": "2025-12-20T09:00:00Z"
}
```

## Reviews
Screens: `Reviews` (Given / Received).

- GET `/reviews`
  - Query: `userId`, `type` = `given | received`, `page`, `pageSize`
  - 200: `{ items: [Review], total }`
- POST `/reviews`
  - Body: `{ productId, toUserId, rating, comment }`
  - 201: `Review`

Review
```json
{
  "id": "uuid",
  "product": {"id": "uuid", "title": "Calculus Textbook"},
  "fromUser": {"id": "uuid", "name": "You"},
  "toUser": {"id": "uuid", "name": "Seller"},
  "rating": 5,
  "comment": "Excellent condition!",
  "createdAt": "2025-12-21T08:00:00Z"
}
```

## Orders
Screens: `Order History`, `Buy Now` flow.

- GET `/orders`
  - 200: `{ items: [Order], total }`
- POST `/orders`
  - Body: `{ productId, quantity=1, address?, notes? }`
  - 201: `Order`
- GET `/orders/{id}`
  - 200: `Order`

Order
```json
{
  "id": "ORD-2025-0001",
  "product": {"id": "uuid", "title": "Modern Desk Lamp"},
  "price": 165,
  "seller": {"id": "uuid", "name": "Emma L."},
  "buyer": {"id": "uuid", "name": "Student User"},
  "status": "Delivered", // Processing | In Transit | Delivered | Canceled
  "createdAt": "2025-12-18T12:00:00Z"
}
```

## Admin
Screen: `Admin Login` (basic admin ops via dashboard later).

- GET `/admin/listings`
  - Query: `status=pending|reported|all`
  - 200: `{ items: [Product], total }`
- PATCH `/admin/listings/{id}/status`
  - Body: `{ status: "archived" | "available" | "removed" }`
  - 200: `Product`
- GET `/admin/users`
  - Query: `search`, `page`, `pageSize`
  - 200: `{ items: [User], total }`

## Validation Rules (aligned with app)
- `email`: must match `/^[^@]+@zzu\.edu\.cn$/`
- `password`: minLength 6
- `name`: minLength 2
- `studentId`: minLength 6
- `price`: number > 0
- `title`: non-empty, maxLength 120
- `description`: maxLength 5000

## Response Wrappers & Pagination
Use consistent wrappers for list endpoints:
```json
{
  "items": [/* ... */],
  "page": 1,
  "pageSize": 20,
  "total": 456
}
```

## Security & Ops
- JWT access tokens (short TTL) + refresh tokens (long TTL)
- Role-based access: `user`, `admin`
- CORS: allow app origins
- Rate limiting: e.g., `/auth/*` stricter
- Input validation on all endpoints
- XSS-safe text fields
- Image scanning / size caps on uploads

## WebSocket (optional)
For real-time chat/notifications:
- Socket namespace: `/ws`
- Events: `message:new`, `conversation:typing`, `notification:new`

## Versioning
- Prefix `/v1` in paths; plan for `/v2` as needed

## Environment & Config
- `.env`: `PORT`, `DATABASE_URL`, `JWT_SECRET`, `REFRESH_SECRET`, `CORS_ORIGINS`
- Database: relational (PostgreSQL) recommended; entities map directly to models above

## Next Steps to Implement
1. Scaffold project and auth (signup/login/refresh).
2. Implement categories and products CRUD + uploads.
3. Implement search, wishlist, and profile endpoints.
4. Add messaging and notifications.
5. Add reviews and orders.
6. Admin moderation endpoints.
7. Harden security, logging, and monitoring.

This spec directly supports all screens in the app: Login/SignUp/Admin/Forgot, Home/Categories/Featured, Search, Product Detail, Sell, My Listings, Wishlist, Messages, Notifications, Reviews, Order History, and Profile.