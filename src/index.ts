#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { WebSocketServerTransport } from "@modelcontextprotocol/sdk/server/websocket.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import express from "express";
import { WebSocketServer } from "ws";
import http from "http";

// Configuration
const MODE = process.env.MCP_MODE || "stdio"; // "stdio" or "http"
const PORT = parseInt(process.env.PORT || "3000", 10);

// Define the tools
const TOOLS: Tool[] = [
  {
    name: "echo",
    description: "Echoes back the provided message",
    inputSchema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "The message to echo back",
        },
      },
      required: ["message"],
    },
  },
  {
    name: "add",
    description: "Adds two numbers together",
    inputSchema: {
      type: "object",
      properties: {
        a: {
          type: "number",
          description: "The first number",
        },
        b: {
          type: "number",
          description: "The second number",
        },
      },
      required: ["a", "b"],
    },
  },
  {
    name: "get_timestamp",
    description: "Returns the current timestamp in ISO 8601 format",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
];

// Create server instance
function createMCPServer() {
  const server = new Server(
    {
      name: "mcp-server-joeleesuh",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // Handler for listing available tools
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: TOOLS,
    };
  });

  // Handler for tool execution
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      switch (name) {
        case "echo": {
          const message = args?.message as string;
          if (!message) {
            throw new Error("Message is required");
          }
          return {
            content: [
              {
                type: "text",
                text: message,
              },
            ],
          };
        }

        case "add": {
          const a = args?.a as number;
          const b = args?.b as number;
          if (typeof a !== "number" || typeof b !== "number") {
            throw new Error("Both 'a' and 'b' must be numbers");
          }
          const result = a + b;
          return {
            content: [
              {
                type: "text",
                text: `${a} + ${b} = ${result}`,
              },
            ],
          };
        }

        case "get_timestamp": {
          const timestamp = new Date().toISOString();
          return {
            content: [
              {
                type: "text",
                text: timestamp,
              },
            ],
          };
        }

        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text",
            text: `Error: ${errorMessage}`,
          },
        ],
        isError: true,
      };
    }
  });

  return server;
}

// Start server in stdio mode
async function startStdioMode() {
  const server = createMCPServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("MCP Server running on stdio");
}

// Start server in HTTP/WebSocket mode
async function startHttpMode() {
  const app = express();
  const httpServer = http.createServer(app);
  const wss = new WebSocketServer({ server: httpServer });

  // Health check endpoint
  app.get("/health", (req, res) => {
    res.json({ status: "ok", mode: "http", version: "1.0.0" });
  });

  // Root endpoint
  app.get("/", (req, res) => {
    res.json({
      name: "mcp-server-joeleesuh",
      version: "1.0.0",
      description: "MCP server with echo, add, and timestamp tools",
      websocket: "ws://" + req.headers.host + "/mcp",
      tools: TOOLS.map((t) => ({ name: t.name, description: t.description })),
    });
  });

  // WebSocket connection handler
  wss.on("connection", async (ws) => {
    console.error("New WebSocket connection established");

    const server = createMCPServer();
    const transport = new WebSocketServerTransport(ws);

    try {
      await server.connect(transport);
      console.error("MCP server connected via WebSocket");
    } catch (error) {
      console.error("Error connecting MCP server:", error);
      ws.close();
    }

    ws.on("close", () => {
      console.error("WebSocket connection closed");
    });

    ws.on("error", (error) => {
      console.error("WebSocket error:", error);
    });
  });

  httpServer.listen(PORT, () => {
    console.error(`MCP Server running on http://localhost:${PORT}`);
    console.error(`WebSocket endpoint: ws://localhost:${PORT}/`);
    console.error(`Health check: http://localhost:${PORT}/health`);
  });
}

// Main entry point
async function main() {
  console.error(`Starting MCP Server in ${MODE} mode...`);

  if (MODE === "http") {
    await startHttpMode();
  } else {
    await startStdioMode();
  }
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
