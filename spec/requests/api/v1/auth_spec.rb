require 'swagger_helper'

RSpec.describe 'api/v1/auth', type: :request do

  path '/api/v1/auth/phone/send' do
    post('send phone code') do
      tags 'Auth'
      consumes 'application/json'
      parameter name: :phone_data, in: :body, schema: {
        type: :object,
        properties: {
          phone: { type: :string, example: '79991234567' }
        },
        required: [ 'phone' ]
      }

      response(200, 'successful') do
        schema type: :object, properties: {
          message: { type: :string, example: 'Код отправлен' }
        }
        run_test!
      end

      response(422, 'unprocessable entity') do
        run_test!
      end
    end
  end

  path '/api/v1/auth/phone/verify' do
    post('verify phone code') do
      tags 'Auth'
      consumes 'application/json'
      parameter name: :verify_data, in: :body, schema: {
        type: :object,
        properties: {
          phone: { type: :string, example: '79991234567' },
          code: { type: :string, example: '1234' },
          cart_token: { type: :string, example: 'guest_token_123' }
        },
        required: %w[phone code]
      }

      response(200, 'successful login') do
        schema type: :object, properties: {
          token: { type: :string },
          user: {
            type: :object,
            properties: {
              id: { type: :integer },
              username: { type: :string },
              phone: { type: :string },
              role: { type: :string }
            }
          },
          is_new: { type: :boolean }
        }
        run_test!
      end

      response(201, 'user created') do
        run_test!
      end

      response(401, 'unauthorized') do
        run_test!
      end
    end
  end
end
