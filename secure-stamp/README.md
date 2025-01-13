# AuthContract SupplyChaincontract, Product-Contract README

## Added Features

1. **Product Registration**: Users can register products with unique identifiers, serial numbers, batch numbers, and expiration dates.
2. **Product Verification**: Allows users to verify products using their product IDs and serial numbers.
3. **Transaction Tracking**: Records the history of product transactions, such as production and shipping.
4. **Field Updates**: Enables updating specific fields of a registered product.

## Smart Contract Structure

### Data Maps

- **products**: Stores information about products, including their authenticity status, product information, serial numbers, batch numbers, and expiration dates.
  
- **serial-to-product-id**: Maps serial numbers to their corresponding product IDs for quick verification.

- **verification-history**: Maintains a history of verifications for each product ID.

- **transaction-history**: Keeps track of product transactions, allowing for auditing and validation of product movement.

### Constants

Defines standard error messages to ensure clear feedback on operations, such as:

- `ERR_PRODUCT_EXISTS`
- `ERR_PRODUCT_NOT_FOUND`
- `ERR_INVALID_FIELD`
- `ERR_CANNOT_UPDATE`
- `ERR_INVALID_TRANSACTION_TYPE`

### Public Functions

1. **register-product**:
   - Registers a new product.
   - **Parameters**:
     - `product-id`: Unique identifier for the product.
     - `serial-number`: Serial number of the product.
     - `batch-number`: Batch number of the product.
     - `expiration-date`: Expiration date of the product.
   - **Returns**: Success or error message.

2. **update-product**:
   - Updates specific fields of a registered product.
   - **Parameters**:
     - `product-id`: Unique identifier of the product to be updated.
     - `field`: Field to update (e.g., "serial-number", "batch-number", "expiration-date").
     - `value`: New value for the field.
   - **Returns**: Success or error message.

3. **verify-product**:
   - Verifies the authenticity of a product by its product ID.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
   - **Returns**: Product information if valid, or an error.

4. **verify-by-serial**:
   - Verifies the authenticity of a product by its serial number.
   - **Parameters**:
     - `serial-number`: Serial number of the product.
   - **Returns**: Product information if valid, or an error.

5. **update-verification-history**:
   - Updates the verification history for a product.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
     - `consumer-id`: ID of the consumer verifying the product.
     - `timestamp`: Time of verification.
   - **Returns**: Success message.

6. **record-transaction**:
   - Records a transaction related to a product.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
     - `transaction-type`: Type of transaction (e.g., "produced", "shipped").
     - `timestamp`: Time of the transaction.
   - **Returns**: Success or error message.

### Read-Only Functions

1. **get-product**:
   - Retrieves details of a registered product.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
   - **Returns**: Product details or an error.

2. **get-verification-history**:
   - Retrieves the verification history of a product.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
   - **Returns**: Verification history or an error.

3. **validate-movement**:
   - Validates if a product can be moved based on its transaction history.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
   - **Returns**: True or false based on validation.

4. **get-transaction-history**:
   - Retrieves the transaction history for a product.
   - **Parameters**:
     - `product-id`: Unique identifier of the product.
   - **Returns**: Transaction history or an error.

## Getting Started

### Prerequisites

- A blockchain environment that supports Clarity smart contracts.
- Access to a wallet with sufficient funds for deploying contracts and executing transactions.

### Deployment

1. Deploy the contract to the blockchain.
2. Initialize the state by adding products as needed.

### Example Usage

```clarity
;; Register a product
(register-product 1 "SN12345" "Batch001" "2025-12-31")

;; Verify a product
(verify-product 1)

;; Update a product field
(update-product 1 "expiration-date" "2026-12-31")

;; Record a transaction
(record-transaction 1 "produced" 1627551234)

;; Get transaction history
(get-transaction-history 1)
```

## Conclusion

The added **SecureStamp features** provides a robust solution for managing product authentication and tracking within a supply chain. With the ability to verify products, track transactions, and update product information, this contract supports transparency and accountability in product management.

For any questions or contributions, feel free to reach out!
