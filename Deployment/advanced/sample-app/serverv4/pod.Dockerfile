FROM python:3.8-slim

WORKDIR /working_dir

COPY pip.conf /etc/pip.conf

RUN pip install -U pip &&\
    pip install --upgrade setuptools wheel pipenv

COPY Pipfile /working_dir/
COPY Pipfile.lock /working_dir/

# Only install needed packages, not the dev ones
RUN pipenv sync

COPY run.py ./run.py

ENV FLASK_APP run.py
ENTRYPOINT ["pipenv", "run", "python", "-m" , "flask", "run", "--port", "8080", "--host", "0.0.0.0"]

EXPOSE 8080/tcp

