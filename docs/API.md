# FoodShare API Documentation

## Base URL
```
https://api.foodshare.club
```

## Authentication
All authenticated endpoints require a Bearer token:
```
Authorization: Bearer <supabase_jwt_token>
```

---

## Endpoints

### Authentication

#### POST /auth/v1/signup
Sign up a new user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Response:**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  },
  "session": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token"
  }
}
```

#### POST /auth/v1/token?grant_type=password
Sign in an existing user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

---

### Listings

#### GET /rest/v1/listings
Get all listings.

**Query Parameters:**
- `status=eq.available` - Filter by status
- `order=created_at.desc` - Sort order
- `limit=20` - Limit results

**Response:**
```json
[
  {
    "id": 1,
    "title": "Fresh Apples",
    "description": "Organic apples",
    "user_id": "uuid",
    "image_url": "https://...",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "status": "available",
    "created_at": "2026-01-01T00:00:00Z"
  }
]
```

#### POST /rest/v1/listings
Create a new listing.

**Request:**
```json
{
  "title": "Fresh Apples",
  "description": "Organic apples",
  "image_url": "https://...",
  "status": "available"
}
```

#### PATCH /rest/v1/listings?id=eq.1
Update a listing.

**Request:**
```json
{
  "title": "Updated Title",
  "status": "claimed"
}
```

#### DELETE /rest/v1/listings?id=eq.1
Delete a listing.

---

### Messages

#### GET /rest/v1/messages
Get messages for current user.

**Query Parameters:**
- `or=(sender_id.eq.uuid,receiver_id.eq.uuid)`
- `order=created_at.asc`

#### POST /rest/v1/messages
Send a message.

**Request:**
```json
{
  "receiver_id": "uuid",
  "content": "Hello!"
}
```

---

### Profiles

#### GET /rest/v1/profiles?id=eq.uuid
Get user profile.

#### PATCH /rest/v1/profiles?id=eq.uuid
Update profile.

**Request:**
```json
{
  "username": "newusername",
  "bio": "My bio",
  "location": "San Francisco"
}
```

---

### Challenges

#### GET /rest/v1/challenges
Get all challenges.

#### POST /rest/v1/challenge_participants
Join a challenge.

**Request:**
```json
{
  "challenge_id": 1
}
```

---

### Comments

#### GET /rest/v1/comments?listing_id=eq.1
Get comments for a listing.

#### POST /rest/v1/comments
Post a comment.

**Request:**
```json
{
  "listing_id": 1,
  "content": "Great item!"
}
```

---

### Activity

#### GET /rest/v1/activities
Get activity feed.

**Query Parameters:**
- `order=created_at.desc`
- `limit=50`

---

## Error Responses

```json
{
  "error": "error_code",
  "message": "Human readable error message"
}
```

**Common Error Codes:**
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `500` - Internal Server Error

---

## Rate Limits

- **Authenticated**: 100 requests/minute
- **Unauthenticated**: 20 requests/minute

---

## Real-time Subscriptions

Subscribe to real-time updates using Supabase Realtime:

```swift
let channel = supabase.channel("listings")
channel.on("INSERT", table: "listings") { message in
    // Handle new listing
}
channel.subscribe()
```

---

**Last Updated**: 2026-02-12
**Version**: 1.0.0
