# Biblioteca de Lucca

Una aplicación Flutter para gestionar tu colección personal de cómics y manga. Diseñada con un estilo visual de cómic, perfecta para jóvenes lectores.

## Capturas de pantalla

*Próximamente*

## Características

### Gestión de biblioteca
- **Tres estados de lectura**: Leyendo, Completados y Lista de deseos
- **Organización por series**: Los cómics se agrupan automáticamente por serie
- **Índice alfabético**: Navegación rápida en colecciones grandes (A-Z + números)
- **Archivar series**: Oculta series completadas sin eliminarlas
- **Progreso de lectura**: Seguimiento de páginas leídas por cómic

### Búsqueda y añadir cómics
- **Escáner de código de barras**: Escanea el ISBN para añadir cómics rápidamente
- **Búsqueda por título**: Encuentra cómics buscando por nombre
- **Búsqueda de colecciones**: Añade series completas de una vez
- **Entrada manual**: Crea entradas personalizadas si no se encuentra el cómic

### Fuentes de datos
- **Tebeosfera**: Base de datos española de cómics
- **Tomos y Grapas**: Información de ediciones españolas
- **Google Books**: Cobertura internacional
- **Open Library**: Datos abiertos de libros

### Sincronización y backup
- **Firebase Cloud**: Sincroniza tu biblioteca entre dispositivos
- **Copia de seguridad completa**: Exporta/importa ZIP con base de datos y portadas
- **Exportar a CSV**: Lista de cómics en formato tabla
- **Exportar a PDF**: Catálogo visual de tu colección

### Características adicionales
- **Modo offline**: Portadas descargadas localmente
- **Notificaciones de continuación**: Aviso cuando hay nuevo volumen disponible
- **Enviar lista por email**: Comparte tu lista de deseos
- **Autenticación Google**: Login seguro con tu cuenta de Google

## Tecnologías

- **Flutter 3.10+** - Framework multiplataforma
- **Firebase** - Auth, Firestore para sincronización
- **SQLite** - Base de datos local
- **Provider** - Gestión de estado

## Requisitos

- Flutter SDK ^3.10.7
- Dart SDK ^3.0.0
- Android SDK 21+ / iOS 12+
- Cuenta de Firebase (para sincronización)

## Instalación

1. Clona el repositorio:
```bash
git clone https://github.com/TU_USUARIO/biblioteca_lucca.git
cd biblioteca_lucca
```

2. Instala las dependencias:
```bash
flutter pub get
```

3. Configura Firebase:
   - Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
   - Descarga `google-services.json` (Android) y `GoogleService-Info.plist` (iOS)
   - Colócalos en sus respectivas carpetas

4. Ejecuta la aplicación:
```bash
flutter run
```

## Estructura del proyecto

```
lib/
├── config/          # Configuración (HTTP, timeouts)
├── constants/       # Constantes (traducciones)
├── models/          # Modelos de datos (Book)
├── screens/         # Pantallas de la app
├── services/        # Servicios (API, DB, sync, backup)
│   └── api/         # Clientes de APIs externas
├── theme/           # Tema visual estilo cómic
├── utils/           # Utilidades (retry HTTP)
└── widgets/         # Widgets reutilizables
```

## APIs utilizadas

| API | Uso | Documentación |
|-----|-----|---------------|
| Tebeosfera | Cómics españoles | [tebeosfera.com](https://www.tebeosfera.com) |
| Tomos y Grapas | Ediciones españolas | [tomosygrapas.com](https://tomosygrapas.com) |
| Google Books | Búsqueda internacional | [developers.google.com/books](https://developers.google.com/books) |
| Open Library | Datos abiertos | [openlibrary.org/developers](https://openlibrary.org/developers) |

## Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Haz fork del proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -m 'Añade nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## Autor

Desarrollado con Claude Code.

---

*Biblioteca de Lucca - Gestiona tu colección de cómics con estilo*
