import getpass
import urllib.request as request
from urllib.error import HTTPError
from xml.etree import ElementTree
import sys

__author__ = 'rf9'


class ClarityException(Exception):
    pass


class Clarity:
    def __init__(self, root):
        if root[-1] != '/':
            root += "/"
        self.root = root

        user = getpass.getuser()
        user = input("Username (leave blank for '" + user + "'): ") or user
        password = getpass.getpass('Password: ')

        try:
            self.setup_urllib(user, password)
        except HTTPError as err:
            if err.msg == "Unauthorized":
                sys.stderr.write("Invalid username or password\n")
            else:
                sys.stderr.write("Invalid root uri\n")
            sys.exit(1)

        self.cache = {}

    def setup_urllib(self, user, password):
        password_mgr = request.HTTPPasswordMgrWithDefaultRealm()
        password_mgr.add_password(None, self.root, user, password)
        handler = request.HTTPBasicAuthHandler(password_mgr)
        opener = request.build_opener(handler)
        opener.open(self.root)
        request.install_opener(opener)

    def get_xml(self, uri, use_cache=True):
        if use_cache and uri in self.cache:
            print('From cache:  ' + uri)
            return self.cache[uri]

        print('Downloading: ' + uri)

        xml = request.urlopen(uri)

        self.cache[uri] = xml
        return ElementTree.parse(xml).getroot()

    def batch_get_xml(self, object_type, uri_list):
        if object_type not in ('artifacts', 'containers', 'files', 'samples'):
            raise ClarityException("Cannot batch %r" % object_type)

        builder = ElementTree.TreeBuilder()
        builder.start('ri:links', {
            'xmlns:ri': "http://genologics.com/ri",
        })
        element = builder.close()

        for uri in uri_list:
            child = ElementTree.TreeBuilder().start('link', {
                'uri': uri,
                'rel': object_type,
            })
            element.append(child)

        req = request.Request(url=(self.root + object_type + '/batch/retrieve'), data=ElementTree.tostring(element),
                              method='POST')
        req.add_header("Content-Type", "application/xml")

        try:
            with request.urlopen(req) as response:
                return ElementTree.parse(response).getroot().getchildren()
        except HTTPError as err:
            sys.stderr.write("Invalid root uri\n")
            sys.exit(1)
