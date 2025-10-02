FROM node:20-alpine

# Install git and other dependencies
RUN apk add --no-cache git python3 make g++

# Clone Open5GS WebUI
RUN git clone https://github.com/open5gs/open5gs.git /open5gs

# Navigate to WebUI directory and install dependencies
WORKDIR /open5gs/webui
RUN npm install

# Expose port
EXPOSE 3000

# Start the WebUI
CMD ["npm", "run", "dev"]

