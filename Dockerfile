# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

FROM centos:7.4.1708

# o/s dependencies
RUN yum install -y curl gcc gettext httpd mod_wsgi postgresql postgresql-devel postgresql-libs python-devel patch \
    && curl -s https://bootstrap.pypa.io/get-pip.py | python \
    && pip install virtualenv

# create autoland user and /repos
RUN adduser autoland \
    && mkdir /repos /home/autoland/autoland /home/autoland/docker /etc/mercurial \
    && chown -R autoland:autoland /repos /home/autoland /etc/mercurial

# copy docker related files
COPY docker /home/autoland/docker
COPY docker/httpd.conf /etc/httpd/conf

# setup the autoland virtualenv
USER autoland
COPY requirements.txt /home/autoland
RUN virtualenv /home/autoland/venv \
    && /home/autoland/venv/bin/pip install -r /home/autoland/requirements.txt
USER root

# make hg a global command
RUN ln -s /home/autoland/venv/bin/hg /usr/bin/hg

# deploy autoland code
COPY autoland /home/autoland/autoland
RUN chown -R autoland:autoland /home/autoland/autoland \
    && chmod 755 /home/autoland

# set SRC_PATH to the path to our autoland/ src directory
# defaults to using the src as image build time
ENTRYPOINT ["/home/autoland/docker/entrypoint.sh"]
CMD ["help"]
