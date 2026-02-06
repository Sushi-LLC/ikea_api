# Project Context: IKEA API

## Overview
This project is a Ruby on Rails API for a service that parses IKEA products and allows users to browse, manage carts, and place orders.

## Key Features
- **Product Catalog**: Parsing and displaying IKEA products with categories, filters, and bestsellers.
- **Authentication**: 
    - Traditional (Username/Password)
    - Phone-based (SMS code verification, automatic registration)
- **Cart System**: 
    - Guest carts (tokenized)
    - Authorized user carts (synced to DB)
    - Automatic cart merging upon login
    - Dynamic rules (min order sum, free delivery thresholds)
- **Checkout**: 
    - Order creation with validation (stock, min sum)
    - Multiple delivery and payment methods
    - Address handling (JSON-based)
- **Admin Panel**: Trestle-based administration for managing products, categories, orders, and calculator settings.

## Tech Stack
- **Ruby on Rails** (API Mode)
- **PostgreSQL**
- **JWT** for authentication
- **Trestle** for its administration panel
- **Swagger/Rswag** for API documentation

## Important Components
- `PhoneAuthService`: Handles phone verification and user auto-creation.
- `CartMergeService`: Merges guest session items into user accounts.
- `CheckoutService`: Validates and creates orders.
- `CartPricingService`: Calculates totals, weights, and applies dynamic rules/promos.
- `CalculatorSetting`: Key-value store for marketing and delivery constants (min order, etc.).

## Delivery Integrations (Planned/In Progress)
- **Europost (Европочта)**
- **Autolight (Автолайт)**
- Tracking via `track_number` in `orders` table.

## Structure
- `app/controllers/api/v1/`: API endpoints.
- `app/models/`: Database models and validations.
- `app/services/`: Business logic and external integrations.
- `app/admin/`: Trestle admin definitions.
- `swagger/v1/swagger.yaml`: OpenAPI 3.0 documentation.
