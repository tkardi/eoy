from django import template

register = template.Library()

@register.filter
def get_value(obj, key):
    return getattr(obj, key, None)

@register.filter
def get_item(dictionary, key):
    return dictionary.get(key)

@register.filter
def get_uri(dictionary):
    if hasattr(dictionary, 'get'):
        return dictionary.get("@id")

@register.simple_tag
def query_transform(request, **kwargs):
    params = request.GET.copy()
    params.update(kwargs)
    return '?%s' % params.urlencode() if params else ''

@register.filter
def to_geojson(obj, key):
    geom = getattr(obj, key, None)
    if geom != None and hasattr(geom, 'geojson'):
        return geom.geojson
    return None
