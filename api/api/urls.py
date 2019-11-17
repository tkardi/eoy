# -*- coding: utf-8 -*-
"""api URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/1.8/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  url(r'^$', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  url(r'^$', Home.as_view(), name='home')
Including another URLconf
    1. Add a URL to urlpatterns:  url(r'^blog/', include('blog.urls'))
"""
from django.conf.urls import url
from django.urls import include, path
from django.contrib import admin
from rest_framework.urlpatterns import format_suffix_patterns
from conf.settings import INSTALLED_APPS_X

from eoy import views

urlpatterns = [
    #url(r'^admin/', include(admin.site.urls)),
    url(r'^$', views.index, name='home'),
    url(
        r'^current/locations/$', views.LocTableAsList.as_view(),
        name='locations-list'),
    url(
        r'^current/trips/$', views.index,
        name='trips-list'),
    url(
        r'^current/flightradar/$', views.flightradar,
        name='flights-list'),
    url(
        r'^current/traingps/$', views.traingps,
        name='trains-list'),
]

## add some extra urls
for app in INSTALLED_APPS_X:
    urlpatterns.append(
        path('', include('%s.urls' % app)),
    )

urlpatterns = format_suffix_patterns(urlpatterns, allowed=['json', 'html'])
