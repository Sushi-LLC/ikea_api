require 'swagger_helper'

RSpec.describe 'api/v1/checkout', type: :request do

  path '/api/v1/checkout' do
    post('create checkout') do
      tags 'Checkout'
      consumes 'application/json'
      security [ bearer_auth: [] ]
      parameter name: :checkout_data, in: :body, schema: {
        type: :object,
        properties: {
          full_name: { type: :string, example: 'Иван Иванов' },
          phone: { type: :string, example: '79991234567' },
          delivery_type: { type: :string, example: 'courier' },
          payment_method: { type: :string, example: 'card' },
          address: {
            type: :object,
            properties: {
              city: { type: :string },
              street: { type: :string }
            }
          }
        }
      }

      response(201, 'order created') do
        schema type: :object, properties: {
          message: { type: :string, example: 'Заказ успешно оформлен' },
          order_id: { type: :integer }
        }
        run_test!
      end

      response(401, 'unauthorized') do
        run_test!
      end

      response(422, 'unprocessable entity') do
        schema type: :object, properties: {
          error: { type: :string }
        }
        run_test!
      end
    end
  end
end
