from rest_framework import serializers
from incidents.models import Incident


class IncidentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Incident
        fields = ["id", "title", "severity", "status", "reporter", "created_at"]
