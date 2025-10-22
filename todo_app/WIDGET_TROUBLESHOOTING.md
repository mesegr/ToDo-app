# Solución de Problemas - Widget no aparece

## Problema: El widget no aparece en la lista de widgets

### Solución 1: Reinstalación completa

1. **Desinstala la app** completamente del dispositivo:
   ```
   Configuración > Aplicaciones > Todo App > Desinstalar
   ```

2. **Limpia el proyecto**:
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Compila e instala de nuevo**:
   ```bash
   flutter build apk --debug
   flutter install
   ```
   O simplemente:
   ```bash
   flutter run
   ```

### Solución 2: Verifica que estés usando un dispositivo físico o emulador con API 26+

Los widgets requieren **Android 8.0 (API 26) o superior**.

Para verificar:
```bash
flutter devices
```

Si el emulador es muy antiguo, crea uno nuevo:
- Android Studio > Device Manager > Create Device
- Selecciona un dispositivo con API 31 o superior

### Solución 3: Verifica los archivos del widget

Asegúrate de que existan estos archivos:

✅ `android/app/src/main/kotlin/com/example/todo_app/TodoWidgetProvider.kt`
✅ `android/app/src/main/res/layout/todo_widget.xml`
✅ `android/app/src/main/res/xml/todo_widget_info.xml`
✅ `android/app/src/main/res/values/strings.xml`
✅ `android/app/src/main/res/drawable/widget_background.xml`

### Solución 4: Verifica el AndroidManifest.xml

Debe contener esta sección dentro de `<application>`:

```xml
<!-- Widget para tareas del día -->
<receiver
    android:name=".TodoWidgetProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/todo_widget_info"/>
</receiver>
```

### Solución 5: Verifica errores de compilación

Ejecuta:
```bash
flutter build apk --debug
```

Busca errores relacionados con:
- `R.layout.todo_widget` no encontrado
- `R.xml.todo_widget_info` no encontrado
- `R.string.widget_description` no encontrado
- Errores de Kotlin en `TodoWidgetProvider`

### Solución 6: Prueba en un dispositivo físico

Algunos emuladores tienen problemas mostrando widgets. Prueba en un dispositivo Android real:

1. Habilita **Depuración USB** en tu dispositivo
2. Conecta el dispositivo por USB
3. Ejecuta:
   ```bash
   flutter devices
   flutter run -d <device-id>
   ```

### Solución 7: Verifica la estructura del paquete Kotlin

El archivo `TodoWidgetProvider.kt` debe estar en:
```
android/app/src/main/kotlin/com/example/todo_app/
```

Y debe tener al inicio:
```kotlin
package com.example.todo_app
```

### Solución 8: Fuerza la actualización del widget

Después de instalar la app:

1. Abre la app
2. Añade una tarea
3. Ve a la pantalla principal
4. Mantén presionado > Widgets
5. Busca "Todo App" o "Mis Tareas"

### Solución 9: Revisa los logs de Android

Mientras la app se ejecuta:
```bash
flutter logs
```

O específicamente para errores del widget:
```bash
adb logcat | grep -i widget
adb logcat | grep -i TodoWidgetProvider
```

### Solución 10: Reconstrucción completa de Android

Si nada funciona:

1. **Elimina la carpeta build**:
   ```bash
   rm -rf build
   rm -rf android/app/build
   rm -rf android/build
   ```

2. **Limpia Gradle** (en PowerShell):
   ```powershell
   cd android
   .\gradlew clean
   cd ..
   ```

3. **Reconstruye todo**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --debug
   flutter install
   ```

## Verificación Final

Una vez instalada la app correctamente:

1. **Mantén presionado** en la pantalla principal de Android
2. Toca **"Widgets"**
3. Busca **"Todo App"** en la lista
4. Deberías ver un widget llamado **"Mis Tareas - Hoy"**
5. **Arrastra** el widget a tu pantalla

## Características mínimas requeridas

- ✅ Android 8.0 (API 26) o superior
- ✅ Espacio en pantalla: mínimo 4x2 celdas
- ✅ App instalada correctamente
- ✅ Permisos de almacenamiento concedidos

## Si aún no funciona

Comparte:
1. La salida de `flutter doctor -v`
2. La salida de `flutter build apk --debug` (busca errores)
3. Los logs: `adb logcat | grep -i error`
4. La versión de Android del dispositivo
