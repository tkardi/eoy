# -*- coding: utf-8 -*-
import io
import psycopg2
import requests
import shutil
import tempfile
import unicodecsv
import zipfile

from io import StringIO
import sys, os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ['DJANGO_SETTINGS_MODULE'] = 'api.settings'

from django.db import connections as CONNECTIONS
from conf.settings import DBTABLES, DBSCHEMA

ZIPURL = 'http://www.peatus.ee/gtfs/gtfs.zip'
# FIXME: ZIPURL should be in conf.settings aswell!

class FilteredCSVFile(unicodecsv.DictReader, object):
    """Local helper for reading only specified columns from a csv file.

    It's assumed that row number 1 is the header row.
    """
    def __init__(self, csvfile, fieldnames=None, restkey=None,
                 restval=None, dialect='excel', encoding='utf-8',
                 errors='strict', *args, **kwargs):
        super(FilteredCSVFile, self).__init__(
            csvfile, self.get_csv_header(csvfile), restkey, restval, dialect,
            encoding, errors, *args, **kwargs)
        self._fieldnames = fieldnames

    def get_csv_header(self, fp):
        header = fp.next().strip('\n').split(',')
        return fp.seek(0)

    def cleanup(self, obj):
        if obj == None or obj == "":
            obj = '\N'
        if isinstance(obj, unicode):
            obj = obj.replace('\t', ' ')
            obj = '"%s"' % obj
        return obj

    def next(self):
        row = super(FilteredCSVFile, self).next()
        return ','.join([self.cleanup(row[k]) for k in self._fieldnames])

    def readline(self):
        return self.next()

    def read(self):
        o = io.StringIO()
        encoding = self.reader.encoding
        try:
            while True:
                row = self.next()
                #o.write(u'%s\n' % (row.encode(encoding), ))
                o.write(row)
                o.write(u'\n')
        except StopIteration as si:
            pass
        return o.getvalue()


def download_zip(url, to_path):
    """Download zipfile from url and extract it to to_path.

    Returns the path of extraction.
    """
    filename = url.split('/')[-1]
    r = requests.get(url)
    r.raise_for_status()
    content = io.BytesIO(r.content)
    with zipfile.ZipFile(content) as z:
        z.extractall(to_path)
    return to_path

def get_csv_header(filepath):
    """Retuns csv file's header row."""
    with open(filepath) as n:
        return n.readline().strip('\n').split(',')

def _db_check_table(cursor, dbschema, dbtable):
    """Checks input table's existance in the database.

    Returns a list with table's column names.
    """
    tab = '%s.%s' % (dbschema, dbtable)
    sql = "select array_agg(attname) from pg_attribute " \
          "where attrelid=%s::regclass and not attisdropped and attnum > 0"
    params = (tab,)
    cursor.execute(sql, params)
    return cursor.fetchone()[0]

def _fs_check_csv(path, filename, ext='txt'):
    """Checks if the input csv file really exists.

    Returns a tuple of csv absolute filepath, and headers.
    """
    filename = '%s.%s' % (filename, ext)
    fp = os.path.join(path, filename)
    assert os.path.exists(fp)
    return fp, get_csv_header(fp)

def _get_insert_cols(db_cols, fp_cols, dbschema, tablename):
    """Returns intersection of input column names.

    Use this to figure out which columns need to be read from the csv file.
    """
    cols = list(set(db_cols).intersection(fp_cols))
    assert len(cols) > 0, "%s.%s and %s.csv do not share any columns" % (
        dbschema, dbtable, dbtable)
    return cols

def _db_prepare_truncate(tableschema, tablename):
    """Prepare a truncate statement for a table in the database.

    @FIXME: as this is prone to injection check whether the tablename
    mentioned in args really exists.
    """
    sql = """truncate table %(sch)s.%(tab)s cascade"""
    params = dict(sch=tableschema, tab=tablename)
    return sql % params

#{main

def run():
    """Run data download and database sync operations"""
    try:
        # go get all csv files extracted at to_path.
        # local
        to_path = '/home/tkardi/tmp/gtfs'
        # the real thing
        #to_path = download_zip(ZIPURL, tempfile.mkdtemp(prefix='eoy_'))
        print to_path
        # loop through required files and look for a matching table
        # in the database
        # if found truncate it and insert new rows from the csv file
        # if table not found, raise exception
        # if exception, then rollback and stop whatever was going on
        # all database commands run in a single transaction
        c = CONNECTIONS['sync']
        with c.cursor() as cursor:
            # loop through the list of tables specified at
            # conf.settings.DBTABLES
            for dbtable in DBTABLES:
                # check if table exists in db and get it's columns
                db_cols = _db_check_table(cursor, DBSCHEMA, dbtable)
                # check if file present and get csv header
                fp, fp_cols = _fs_check_csv(to_path, dbtable)
                print '%s.%s' %(DBSCHEMA, dbtable),
                # get intersection of db_cols and fp_cols (i.e cols that
                # are present in both)
                cols = _get_insert_cols(db_cols, fp_cols, DBSCHEMA, dbtable)
                # truncate old data,
                st_trunc = _db_prepare_truncate(DBSCHEMA, dbtable)
                cursor.execute(st_trunc)
                # and fill anew ...
                with open(fp, 'r') as f:
                    csv = FilteredCSVFile(f, fieldnames=cols)
                    tab = '%s.%s' % (DBSCHEMA, dbtable)
                    st_copy = """copy %s (%s) from stdin with null '\N' delimiter ',' csv header encoding 'UTF8'""" % (tab, ','.join(cols))
                    cursor.copy_expert(st_copy, io.StringIO(csv.read()))
                    print cursor.rowcount,
                print 'done %s' % fp
    except:
        raise
    # FIXME: This is the place for calling data prep functions in the database.

    # keep the file for now...
    #shutil.rmtree(to_path)


if __name__ == '__main__':
    run()
    #pass
