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

### Prerequisites

1. Create a GitHub repository for this project
2. Push your code to GitHub
3. Create an account on [smithery.ai](https://smithery.ai)

### Steps to Deploy

1. **Initialize Git Repository** (if not already done):
   ```bash
   git init
   git add .
   git commit -m "Initial commit: MCP Simple Server"
   ```

2. **Push to GitHub**:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/mcp-simple-server.git
   git branch -M main
   git push -u origin main
   ```

3. **Deploy on smithery.ai**:
   - Go to [smithery.ai](https://smithery.ai)
   - Sign in with your GitHub account
   - Click "New Server" or "Deploy Server"
   - Connect your GitHub repository
   - Select the `mcp-simple-server` repository
   - Configure the deployment settings:
     - **Name**: mcp-simple-server
     - **Entry Point**: `dist/index.js`
     - **Build Command**: `npm install && npm run build`
   - Click "Deploy"

4. **Use Your Server**:
   - Once deployed, smithery.ai will provide you with connection details
   - You can use this server with any MCP client (like Claude Desktop)
   - Add the server configuration to your MCP client settings

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
