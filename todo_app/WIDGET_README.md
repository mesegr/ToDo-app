# Widget de Tareas para Android

## Cómo añadir el widget a la pantalla principal

1. **Mantén presionado** en un espacio vacío de tu pantalla principal de Android
2. Selecciona la opción **"Widgets"** o **"Aplicaciones y Widgets"**
3. Busca el widget **"Mis Tareas - Hoy"** de la app Todo App
4. **Arrastra** el widget a tu pantalla principal
5. El widget mostrará automáticamente las tareas de hoy

## Características del widget

- 📊 **Vista de hoy**: Muestra solo las tareas programadas para el día actual
- ⏰ **Tareas con alarma**: Sección especial para tareas que tienen alarma configurada
- 📋 **Tareas pendientes**: Muestra las tareas sin alarma
- ➕ **Botón de añadir**: Toca el botón "+" para abrir la app y añadir una tarea nueva
- 🔄 **Actualización automática**: El widget se actualiza cada vez que añades, editas o eliminas una tarea

## Funcionalidad

### Actualización del widget
El widget se actualiza automáticamente cuando:
- Añades una nueva tarea
- Editas una tarea existente
- Eliminas una tarea
- Marcas una tarea como completada

### Interacción
- **Toca el encabezado** del widget para abrir la app
- **Toca el botón +** para ir directamente a añadir una nueva tarea
- Las tareas se muestran con su hora programada (si tienen)

## Formato de visualización

### Tareas con alarma (⏰)
```
• Nombre de la tarea - HH:mm
• Otra tarea - HH:mm
```

### Tareas pendientes (📋)
```
• Tarea sin alarma - HH:mm
• Otra tarea pendiente - HH:mm
```

### Mensaje vacío
Si no hay tareas para hoy, el widget mostrará:
```
No hay tareas para hoy

Toca + para añadir una
```

## Personalización

El widget utiliza el mismo esquema de colores de la app:
- **Fondo**: Morado oscuro (#1F1A2E)
- **Acentos**: Morado vibrante (#8B5CF6)
- **Texto**: Blanco (#FFFFFF)
- **Bordes**: Morado medio (#3D3350)

## Solución de problemas

### El widget no se actualiza
1. Cierra y vuelve a abrir la app
2. Elimina el widget y vuelve a añadirlo
3. Verifica que la app tenga permisos de almacenamiento

### El widget no aparece en la lista
1. Asegúrate de haber instalado la última versión de la app
2. Reinicia tu dispositivo
3. Verifica que el espacio en el launcher sea suficiente (mínimo 4x2 celdas)

### El botón + no funciona
1. Verifica que la app esté instalada correctamente
2. Prueba tocando el encabezado del widget
3. Abre la app manualmente y verifica que funcione

## Notas técnicas

- **Tamaño mínimo**: 250dp x 120dp (aproximadamente 4x2 celdas)
- **Redimensionable**: Sí, horizontal y vertical
- **Frecuencia de actualización**: Cada 30 minutos (más actualizaciones manuales)
- **Almacenamiento**: Utiliza SharedPreferences para sincronizar datos
