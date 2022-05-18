# -*- coding: utf-8 -*-
import io
import psycopg2
import requests
import shutil
import tempfile
import csv #unicodecsv
import time
import zipfile

from io import StringIO
import sys, os

from app.load_resources import settings

_PATH = os.path.dirname(__file__)

class FilteredCSVFile(csv.DictReader, object):
    """Local helper for reading only specified columns from a csv file.

    It's assumed that row number 1 is the header row.
    """
    def __init__(
        self, csvfile, fieldnames=None, restkey=None, restval=None,
        dialect='excel', *args, **kwargs):
        self._header = self.get_csv_header(csvfile)
        super(FilteredCSVFile, self).__init__(
            csvfile, self._header , restkey, restval,
            dialect, *args, **kwargs)
        self._fieldnames = fieldnames

    def get_csv_header(self, fp):
        return fp.readline().strip('\n').split(',')

    def cleanup(self, obj):
        if obj == None or obj == "":
            obj = '\\N'
        if isinstance(obj, str):
            obj = obj.replace('\t', ' ')
            if ',' in obj:
                obj = '"%s"' % obj
        return obj

    def next(self):
        row = dict(zip(self._header, next(self.reader)))
        return '\t'.join(['%s' % self.cleanup(row[k]) for k in self._fieldnames])

    def readline(self):
        return self.next()

    def read(self):
        o = io.StringIO()
        try:
            while True:
                row = self.next()
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
    tab = f'{dbschema}.{dbtable}'
    sql = "select array_agg(attname) from pg_attribute " \
          "where attrelid=%s::regclass and not attisdropped and attnum > 0"
    params = (tab,)
    cursor.execute(sql, params)
    return cursor.fetchone()[0]

def _fs_check_csv(path, filename, ext='txt'):
    """Checks if the input csv file really exists.

    Returns a tuple of csv absolute filepath, and headers.
    """
    filename = f'{filename}.{ext}'
    fp = os.path.join(path, filename)
    assert os.path.exists(fp)
    return fp, get_csv_header(fp)

def _get_insert_cols(db_cols, fp_cols, dbschema, tablename):
    """Returns intersection of input column names.

    Use this to figure out which columns need to be read from the csv file.
    """
    cols = list(set(db_cols).intersection(fp_cols))
    assert len(cols) > 0, f"{dbschema}.{dbtable} and {dbtable}.csv do not share any columns"
    return cols

def _db_prepare_truncate(tableschema, tablename):
    """Prepare a truncate statement for a table in the database.

    @FIXME: as this is prone to injection check whether the tablename
    mentioned in args really exists.
    """
    sql = f"""truncate table {tableschema}.{tablename} cascade"""
    return sql

#{main

def run():
    """Run data download and database sync operations"""
    try:
        # go get all csv files extracted at to_path.
        # local
        # to_path = 'tmp'
        # the real thing
        to_path = download_zip(settings.GTFS_ZIPURL, tempfile.mkdtemp(prefix='eoy_'))
        print(to_path)
        # loop through required files and look for a matching table
        # in the database
        # if found truncate it and insert new rows from the csv file
        # if table not found, raise exception
        # if exception, then rollback and stop whatever was going on
        # all database commands run in a single transaction
        with psycopg2.connect(**settings.DATABASE) as connection:
            with connection.cursor() as cursor:
                cursor.execute(f'SET search_path={settings.GTFS_DBSCHEMA},"$user",public')
                # loop through the list of tables specified at
                # settings.GTFS_DBTABLES
                for dbtable in settings.GTFS_DBTABLES:
                    # check if table exists in db and get it's columns
                    db_cols = _db_check_table(cursor, settings.GTFS_DBSCHEMA, dbtable)
                    # check if file present and get csv header
                    fp, fp_cols = _fs_check_csv(to_path, dbtable)
                    print (f'{settings.GTFS_DBSCHEMA}.{dbtable}')
                    # get intersection of db_cols and fp_cols (i.e cols that
                    # are present in both)
                    cols = _get_insert_cols(db_cols, fp_cols, settings.GTFS_DBSCHEMA, dbtable)
                    # truncate old data,
                    st_trunc = _db_prepare_truncate(settings.GTFS_DBSCHEMA, dbtable)
                    cursor.execute(st_trunc)
                    # and fill anew ...
                    with open(fp, encoding='utf-8') as f:
                        fcsv = FilteredCSVFile(f, fieldnames=cols, quotechar='"')
                        #tab = '%s.%s' % (settings.GTFS_DBSCHEMA, dbtable)
                        cursor.copy_from(io.StringIO(fcsv.read()), dbtable, sep='\t', columns=cols)
                        print(cursor.rowcount)
                    print(f'done {fp}')
    except:
        raise
    shutil.rmtree(to_path)

def postprocess():
    print("starting postprocess...")
    with psycopg2.connect(**settings.DATABASE) as connection:
        fp = os.path.join(os.path.dirname(_PATH), 'resources', 'db', 'preprocess.sql')
        with open(fp) as f:
            statements = f.read()
        with connection.cursor() as cursor:
            for statement in statements.split(';'):
                if statement.strip() != '':
                    cursor.execute(statement.strip())
    print("postprocess done")


if __name__ == '__main__':
    run()
    postprocess()
    #pass
