FROM ubuntu:14.04

RUN useradd --system -U -u 500 timo
RUN apt-get -y update && apt-get install -y python-dev python-docutils python-virtualenv python-pip zlib1g-dev build-essential libldap2-dev libsasl2-dev libreadline6-dev libncurses5-dev libncursesw5-dev libsqlite3-dev libssl-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libxslt1-dev libpcre3-dev wget git
RUN pip install -U pip virtualenv

#RUN git clone https://github.com/sneridagh/bobtemplates.kitconcept.git /plone
ADD . /plone

RUN cd /plone && wget http://dist.plone.org/release/4.3.7/buildout-cache.tar.bz2 && tar xvfj buildout-cache.tar.bz2 && mv buildout-cache/eggs .
RUN cd /plone && virtualenv --clear . && ./bin/python bootstrap-buildout.py && ./bin/buildout -c deployment.cfg
RUN chown -R timo.timo /plone

EXPOSE 8080

USER timo
WORKDIR /plone

CMD ["/plone/bin/supervisord", "-n"]
