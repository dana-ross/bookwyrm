FROM ubuntu:xenial-20200706 
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
ENV PGPORT 5432

ENV CELERY_BROKER redis://localhost:6379/0
ENV CELERY_RESULT_BACKEND redis://localhost:6379/0

ENV FLOWER_PORT 5555

ENV DEBIAN_FRONTEND noninteractive

RUN apt update
RUN apt install -y software-properties-common
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt update
RUN apt install -y libjpeg-dev nginx postgresql postgresql-contrib postgresql-server-dev-all python3.6 python3.6-dev python3-pip redis-server sudo zlib1g zlib1g-dev 
RUN rm /usr/bin/python3 && ln -s /usr/bin/python3.6 /usr/bin/python3 && ln -s /usr/bin/python3 /usr/local/bin/python
RUN mkdir -p /app && mkdir -p /app/static && mkdir -p /app/images
WORKDIR /app
COPY requirements.txt /app/
RUN cd /app && pip3 install -r requirements.txt
COPY . /app

#RUN service postgresql stop
#RUN mkdir "$PGDATA" && chown postgres:postgres "$PGDATA" && chmod 0700 "$PGDATA" 
RUN mkdir -p /tmp/pgdata && chown postgres:postgres /tmp/pgdata && chmod 0700 /tmp/pgdata
RUN pg_dropcluster 9.5 main
RUN pg_createcluster 9.5 main -d /tmp/pgdata 
RUN sudo -E -u postgres cp /etc/postgresql/9.5/main/postgresql.conf /tmp/pgdata/postgresql.conf
RUN sed -i "s#data_directory = '/var/lib/postgresql/9.5/main'#data_directory = '$PGDATA'#" /tmp/pgdata/postgresql.conf
#RUN sudo -E -u postgres pg_createcluster 9.5 bookwyrm -D "$PGDATA" -p $PGPORT
RUN sudo -E -u postgres /usr/lib/postgresql/9.5/bin/pg_ctl start -D /tmp/pgdata -l /var/log/postgresql/postgresql-9.5-main.log ; sleep 15 ; sudo -E -u postgres psql -p $PGPORT --command "CREATE ROLE fedireads WITH LOGIN PASSWORD 'fedireads';" ; sudo -E -u postgres createdb fedireads -p $PGPORT ; cp /app/.env.example /app/.env ; chown -R postgres:postgres /app/fedireads/migrations ; sudo -E -u postgres /app/rebuilddb.sh ; sudo -E -u postgres /usr/lib/postgresql/9.5/bin/pg_ctl stop -D /tmp/pgdata ; sleep 15
#RUN service postgresql stop

EXPOSE 8000

#CMD ["sh", "-c", "service redis-server start ; sudo -E -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /pg_data start ; cd /app ; ( celery -A fr_celery worker -l info & ) ; python3 manage.py runserver 0.0.0.0:8000"]
#CMD ["sh", "-c", "service redis-server start ; service postgresql stop ; sudo -E -u postgres /usr/lib/postgresql/9.5/bin/pg_ctl -D /pg_data start; cd /app ; ( celery -A fr_celery worker -l info & ) ; python3 manage.py runserver 0.0.0.0:8000"]
CMD sh -c '(test ! -e "$PGDATA" && echo "You need to mount a volume at /pgdata" && exit 1 ) && (test ! -e /pgdata/postgresql.conf && echo "First run -- copying cluster data files to /pgdata volume" && cp -R /tmp/pgdata/* "$PGDATA") ; chown -R postgres:postgres "$PGDATA" ; service redis-server start ; service postgresql stop ; sudo -E -u postgres /usr/lib/postgresql/9.5/bin/pg_ctl start -D "$PGDATA" -l /var/log/postgresql/postgresql-9.5-main.log -s ; sleep 20 ; cd /app ; ( celery -A fr_celery worker -l info & ) ; python3 manage.py runserver 0.0.0.0:8000'

