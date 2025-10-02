# MCP Simple Server

A simple Model Context Protocol (MCP) server with three basic tools: echo, add numbers, and get timestamp.

## Features

- **echo**: Echoes back any message you provide
- **add**: Adds two numbers together
- **get_timestamp**: Returns the current timestamp in ISO 8601 format

## Installation

```bash
npm install
```

## Building

```bash
npm run build
```

## Local Testing

```bash
npm start
```

## Tools

### echo
Echoes back the provided message.

**Arguments:**
- `message` (string, required): The message to echo back

**Example:**
```json
{
  "message": "Hello, World!"
}
```

### add
Adds two numbers together.

**Arguments:**
- `a` (number, required): The first number
- `b` (number, required): The second number

**Example:**
```json
{
  "a": 5,
  "b": 3
}
```

### get_timestamp
Returns the current timestamp in ISO 8601 format.

**Arguments:** None

## Deployment to smithery.ai

This project is configured for deployment on Smithery.ai with:
- `Dockerfile` - Multi-stage Docker build for optimized container image
- `smithery.yaml` - Smithery configuration for stdio-based MCP server
- `.dockerignore` - Excludes unnecessary files from Docker build

### Prerequisites

1. Create a GitHub repository for this project
2. Push your code to GitHub (including Dockerfile and smithery.yaml)
3. Create an account on [smithery.ai](https://smithery.ai)
4. (Optional) Test Docker build locally: `docker build -t mcp-simple-server .`

### Steps to Deploy

1. **Push to GitHub** (if not already done):
   ```bash
   git add .
   git commit -m "Add Smithery deployment configuration"
   git push
   ```

2. **Deploy on smithery.ai**:
   - Go to [smithery.ai](https://smithery.ai)
   - Sign in with your GitHub account
   - Click "New Server" or "Deploy Server"
   - Connect your GitHub repository
   - Select the `mcp-simple-server` repository
   - Smithery will automatically detect `Dockerfile` and `smithery.yaml`
   - Click "Deploy"

3. **Use Your Server**:
   - Once deployed, Smithery will provide installation instructions
   - You can install it with: `npx @smithery/cli install <your-server-name>`
   - Or use it directly in Claude Desktop or other MCP clients

### Example Claude Desktop Configuration

After deployment, add this to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "simple-server": {
      "command": "npx",
      "args": ["-y", "@smithery/mcp-simple-server"]
    }
  }
}
```

Or if testing locally:

```json
{
  "mcpServers": {
    "simple-server": {
      "command": "node",
      "args": ["C:/Users/User/mcp-simple-server/dist/index.js"]
    }
  }
}
```

## Development

### Project Structure

```
mcp-simple-server/
├── src/
│   └── index.ts          # Main server implementation
├── dist/                 # Compiled JavaScript (generated)
├── Dockerfile            # Docker container configuration
├── smithery.yaml         # Smithery deployment configuration
├── .dockerignore         # Docker build exclusions
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
└── README.md            # This file
```

### Adding New Tools

To add new tools, modify `src/index.ts`:

1. Add the tool definition to the `TOOLS` array
2. Add a new case in the `CallToolRequestSchema` handler switch statement
3. Rebuild the project: `npm run build`

## License

MIT
