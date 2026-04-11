from django.urls import path
from incidents import views

urlpatterns = [
    path("api/v1/status", views.health),
    path("api/v1/incidents", views.list_incidents),
    path("api/v1/incidents/<int:incident_id>", views.get_incident),
    path("api/v1/incidents/new", views.create_incident),
    path("", views.root),
]
