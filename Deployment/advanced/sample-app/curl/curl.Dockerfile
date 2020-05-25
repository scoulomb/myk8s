FROM ubuntu

RUN apt-get update && apt-get install -y curl

WORKDIR /working_dir

COPY curl.sh curl.sh
RUN chmod 777 curl.sh

ENTRYPOINT ["sh", "./curl.sh"]
