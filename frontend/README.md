# Aegis

# Frontend Overview

## Tecnologías

- **Flutter** como framework principal.
- **Riverpod** como manejador de estado.
- Uso de widgets con `key` (por ejemplo, `TreeView` personalizado).

---

## Arquitectura

El frontend está organizado en una estructura típica basada en Flutter:

- `screens/` – Pantallas principales.
- `widgets/` – Widgets reutilizables.
- `providers/` – Providers de Riverpod.
- `models/` – Modelos de datos.
- `services/` – Servicios auxiliares (si aplica).

El flujo lógico sigue:

`UI → Providers → Lógica / Datos`

---


## Notas adicionales

- Integración eventual con sistemas de monitoreo o métricas externas.

---
