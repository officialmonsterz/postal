# frozen_string_literal: true

module LegacyAPI
  class OpenapiController < BaseController
    skip_before_action :authenticate_as_server

    # GET /api/v1/openapi.json
    def schema
      host = Postal::Config.postal.web_hostname
      protocol = Postal::Config.postal.web_protocol

      spec = {
        openapi: "3.0.3",
        info: {
          title: "Postal Mail Server API",
          version: (defined?(Postal.version) ? Postal.version : "1.0.0"),
          description: "RESTful API for sending and managing email through Postal. Supports single messages, raw messages, batch sending, and campaign management.",
          contact: {
            name: "Postal Support",
            url: "https://docs.postalserver.io"
          }
        },
        servers: [
          {
            url: "#{protocol}://#{host}/api/v1",
            description: "Postal API server"
          }
        ],
        security: [
          { ApiKeyAuth: [] }
        ],
        components: {
          securitySchemes: {
            ApiKeyAuth: {
              type: "apiKey",
              in: "header",
              name: "X-Server-API-Key",
              description: "Server API key for authentication."
            }
          },
          schemas: {
            MessageRequest: {
              type: "object",
              properties: {
                to: { type: "array", items: { type: "string" }, example: ["user@example.com"] },
                cc: { type: "array", items: { type: "string" } },
                bcc: { type: "array", items: { type: "string" } },
                from: { type: "string", example: "sender@example.com" },
                sender: { type: "string" },
                subject: { type: "string" },
                reply_to: { type: "string" },
                plain_body: { type: "string" },
                html_body: { type: "string" },
                tag: { type: "string" },
                headers: { type: "object" },
                attachments: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      name: { type: "string" },
                      content_type: { type: "string" },
                      data: { type: "string", description: "Base64-encoded file data" }
                    }
                  }
                }
              },
              required: ["to", "from"]
            },
            BatchRequest: {
              type: "object",
              properties: {
                messages: {
                  type: "array",
                  items: { "$ref" => "#/components/schemas/MessageRequest" },
                  description: "Array of messages to send (max 500)"
                }
              },
              required: ["messages"]
            },
            Campaign: {
              type: "object",
              properties: {
                id: { type: "integer" },
                name: { type: "string" },
                status: { type: "string", enum: %w[draft running paused completed] },
                subject_a: { type: "string" },
                subject_b: { type: "string" },
                sender_name: { type: "string" },
                sender_email: { type: "string" },
                reply_to: { type: "string" },
                template_name: { type: "string" },
                total_sent: { type: "integer" },
                total_opened: { type: "integer" },
                total_clicked: { type: "integer" },
                total_failed: { type: "integer" },
                created_at: { type: "number" }
              }
            }
          }
        },
        paths: {
          "/send/message" => {
            post: {
              summary: "Send an email message",
              tags: ["Messages"],
              requestBody: {
                required: true,
                content: {
                  "application/json" => {
                    schema: { "$ref" => "#/components/schemas/MessageRequest" }
                  }
                }
              },
              responses: {
                "200" => { description: "Message accepted" },
                "400" => { description: "Validation error" }
              }
            }
          },
          "/send/raw" => {
            post: {
              summary: "Send a raw email message",
              tags: ["Messages"],
              responses: {
                "200" => { description: "Raw message accepted" }
              }
            }
          },
          "/send/batch" => {
            post: {
              summary: "Send multiple emails in one request (max 500)",
              tags: ["Messages"],
              requestBody: {
                required: true,
                content: {
                  "application/json" => {
                    schema: { "$ref" => "#/components/schemas/BatchRequest" }
                  }
                }
              },
              responses: {
                "200" => { description: "Batch processed" }
              }
            }
          },
          "/campaigns" => {
            get: {
              summary: "List campaigns",
              tags: ["Campaigns"],
              responses: { "200" => { description: "OK" } }
            },
            post: {
              summary: "Create a campaign",
              tags: ["Campaigns"],
              responses: { "200" => { description: "Created" } }
            }
          },
          "/campaigns/{id}" => {
            get: {
              summary: "Get campaign",
              tags: ["Campaigns"],
              parameters: [
                { name: "id", in: "path", required: true, schema: { type: "integer" } }
              ],
              responses: { "200" => { description: "OK" } }
            }
          },
          "/campaigns/{id}/launch" => {
            post: {
              summary: "Launch campaign",
              tags: ["Campaigns"],
              parameters: [
                { name: "id", in: "path", required: true, schema: { type: "integer" } }
              ],
              responses: { "200" => { description: "Launched" } }
            }
          },
          "/campaigns/{id}/pause" => {
            post: {
              summary: "Pause campaign",
              tags: ["Campaigns"],
              parameters: [
                { name: "id", in: "path", required: true, schema: { type: "integer" } }
              ],
              responses: { "200" => { description: "Paused" } }
            }
          },
          "/campaigns/{id}/stats" => {
            get: {
              summary: "Campaign stats",
              tags: ["Campaigns"],
              parameters: [
                { name: "id", in: "path", required: true, schema: { type: "integer" } }
              ],
              responses: { "200" => { description: "OK" } }
            }
          },
          "/campaigns/{id}/recipients" => {
            get: {
              summary: "List recipients",
              tags: ["Campaigns"],
              parameters: [
                { name: "id", in: "path", required: true, schema: { type: "integer" } }
              ],
              responses: { "200" => { description: "OK" } }
            },
            post: {
              summary: "Add recipients",
              tags: ["Campaigns"],
              parameters: [
                { name: "id", in: "path", required: true, schema: { type: "integer" } }
              ],
              responses: { "200" => { description: "OK" } }
            }
          }
        }
      }

      render json: spec
    end
  end
end
