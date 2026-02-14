FROM public.ecr.aws/nginx/nginx:alpine@sha256:ddd8506b6fd36ccb79a7e90231fedb86c27bc900ba7450e977154745995cde77

# Use path relative to repo root when building with: docker build -f docker/Dockerfile -t yo-nginx .
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

