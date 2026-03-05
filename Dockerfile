# ---------- Etapa 1: Build Flutter ----------
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# copiar proyecto
COPY . .

# habilitar web
RUN flutter config --enable-web

# obtener dependencias
RUN flutter pub get

# compilar web en modo release
RUN flutter build web --release


# ---------- Etapa 2: Servidor Caddy ----------
FROM caddy:alpine

# copiar build de flutter
COPY --from=build /app/build/web /usr/share/caddy

# puerto usado por render
EXPOSE 80