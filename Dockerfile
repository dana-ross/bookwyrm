FROM postgres
ENV  PYTHONUNBUFFERED 1

# SECURITY WARNING: keep the secret key used in production secret!
ENV SECRET_KEY 7(2w1sedok=aznpq)ta1mc4i%4h=xx@hxwx*o57ctsuml0x%fr

# SECURITY WARNING: don't run with debug turned on in production!
ENV DEBUG true

ENV DOMAIN localhost

## Leave unset to allow all hosts
# ENV ALLOWED_HOSTS="localhost,127.0.0.1,[::1]"

ENV OL_URL https://openlibrary.org

## Database backend to use.
## Default is postgres, sqlite is for dev quickstart only (NOT production!!!)
ENV FEDIREADS_DATABASE_BACKEND postgres

ENV MEDIA_ROOT images/

ENV POSTGRES_PASSWORD fedireads
ENV POSTGRES_USER fedireads
ENV POSTGRES_DB fedireads
ENV POSTGRES_HOST localhost
ENV PGDATA /pg_data

ENV CELERY_BROKER redis://localhost:6379/0
ENV CELERY_RESULT_BACKEND redis://localhost:6379/0

ENV FLOWER_PORT 5555

RUN mkdir /pg_data && chown postgres:postgres /pg_data && chmod 0700 /pg_data

RUN apt update && export DEBIAN_FRONTEND=noninteractive && apt install -y libpq-dev nginx python3.7 python3-pip redis sudo
RUN ln -s `which python3` /usr/local/bin/python
RUN mkdir -p /app
RUN mkdir -p /app/static
RUN mkdir -p /app/images
WORKDIR /app
COPY requirements.txt /app/
RUN cd /app && pip3 install -r requirements.txt
COPY . /app

RUN chown postgres:postgres /pg_data
RUN sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl initdb --pgdata=/pg_data
RUN cp /usr/share/postgresql/postgresql.conf.sample /pg_data/postgresql.conf
RUN sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /pg_data start ; sudo -u postgres /usr/lib/postgresql/12/bin/psql --command "CREATE ROLE fedireads WITH LOGIN PASSWORD 'fedireads';" ; sudo -u postgres /usr/lib/postgresql/12/bin/createdb fedireads ; sudo -u postgres /app/rebuilddb.sh

EXPOSE 8000

CMD ["sh", "-c", "service redis-server start ; sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /pg_data start ; cd /app ; ( celery -A fr_celery worker -l info & ) ; python3 manage.py runserver 0.0.0.0:8000"]
