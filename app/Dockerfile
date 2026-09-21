# Multi-stage build: compile in a full Go image, ship a distroless runtime.
# Distroless = no shell, no package manager, minimal CVE surface, smaller image.
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY src/go.mod src/go.sum ./
RUN go mod download 
COPY src/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app ./main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
