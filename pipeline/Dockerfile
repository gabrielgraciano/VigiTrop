# Pipeline do VigiTrop: PySUS 2.x -> data/ (bronze/silver/gold).
# Uso: docker compose run --rm pipeline <comando>   (ver pipeline/README.md)
FROM python:3.12.16-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    VIGITROP_DADOS=/data

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

# O catálogo do PySUS usa a extensão `ducklake` do DuckDB. Instalada no build,
# ela fica na imagem: o container não precisa baixá-la a cada execução.
RUN python -c "import duckdb; duckdb.execute('INSTALL ducklake'); duckdb.execute('LOAD ducklake')"

COPY config/ config/
COPY vigitrop_pipeline/ vigitrop_pipeline/

VOLUME /data
ENTRYPOINT ["python", "-m", "vigitrop_pipeline"]
CMD ["--help"]
