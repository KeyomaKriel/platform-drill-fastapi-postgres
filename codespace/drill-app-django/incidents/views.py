import socket

from django.db import connection
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from incidents.models import Incident
from incidents.serializers import IncidentSerializer


@api_view(["GET"])
def root(request):
    return Response({
        "app": "incident-api",
        "version": "0.1.0",
        "hostname": socket.gethostname(),
    })


@api_view(["GET"])
def health(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        return Response({"status": "healthy", "service": "incident-api"})
    except Exception as e:
        return Response(
            {"status": "degraded", "error": str(e)},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )


@api_view(["GET"])
def list_incidents(request):
    incidents = Incident.objects.all()
    serializer = IncidentSerializer(incidents, many=True)
    return Response(serializer.data)


@api_view(["GET"])
def get_incident(request, incident_id):
    try:
        incident = Incident.objects.get(pk=incident_id)
    except Incident.DoesNotExist:
        return Response(
            {"error": "not found"},
            status=status.HTTP_404_NOT_FOUND,
        )
    serializer = IncidentSerializer(incident)
    return Response(serializer.data)


@api_view(["POST"])
def create_incident(request):
    serializer = IncidentSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
