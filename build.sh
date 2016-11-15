#!/bin/sh

docker build -t showcase-idx/tileserver-mapnik .
docker tag showcase-idx/tileserver-mapnik us.gcr.io/showcase-idx/tileserver-mapnik:master-$(git rev-parse --short HEAD)

docker login -u _token -p "$(gcloud auth print-access-token)" https://us.gcr.io
gcloud docker push us.gcr.io/showcase-idx/tileserver-mapnik:master-$(git rev-parse --short HEAD)
