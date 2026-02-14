FROM public.ecr.aws/nginx/nginx:alpine

# Use path relative to repo root when building with: docker build -f docker/Dockerfile -t yo-nginx .
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

