# MiAppMercado (Marketplace de Campus) 

Una aplicación móvil desarrollada en **Flutter** diseñada para facilitar la venta de productos (dulces, snacks, accesorios) dentro del campus. La aplicación permite a los vendedores gestionar su perfil de tienda, catálogo de productos, inventario y coordinar entregas de manera eficiente.

El backend está impulsado por **Supabase**, manejando autenticación, base de datos en tiempo real y almacenamiento de imágenes.

## Características Principales

* **Autenticación de Vendedores:** Inicio de sesión y registro seguro (`PantallaAuthVendedor`).
* **Gestión de Perfil de Tienda:** Personaliza el nombre de la tienda, foto de perfil y descripción (`VistaEditarPerfilTienda`).
* **Catálogo de Productos:**

  * Agregar y editar productos con nombre, precio y disponibilidad (`FormularioProducto`).
  * Subida de imágenes de productos utilizando la cámara o galería.
* **Gestión de Entregas y Solicitudes:**

  * Revisar peticiones de entrega de los clientes (`\_verMisSolicitudes`).
  * Proponer nuevas opciones de hora o lugar de entrega.
  * Validación de entregas mediante folios ("¡Entrega validada!").
* **Escáner Integrado:** Lector de códigos QR/Barras integrado para gestión rápida (`PantallaEscaner`).

## Tecnologías y Paquetes

* **Frontend:** [Flutter](https://flutter.dev/) \& Dart
* **Backend:** [Supabase](https://supabase.com/) (Auth, Database, Storage, Realtime)
* **Dependencias principales:**

  * `supabase\_flutter`: Integración con el backend.
  * `mobile\_scanner`: Escaneo de códigos QR y códigos de barras.
  * `image\_picker`: Selección de fotos desde la cámara y la galería.
  * `shared\_preferences`: Almacenamiento local de datos de sesión.
  * `url\_launcher`: Apertura de enlaces externos.

## Configuración e Instalación

1. **Clonar el repositorio:**

```bash
   git clone https://github.com/tu-usuario/miappmercado.git
   cd miappmercado
   ```

2. **Instalar dependencias:**

```bash
   flutter pub get
   ```

3. **Configurar Supabase:**
Crea un archivo `.env` en la raíz del proyecto (o configura las variables en tu archivo de constantes) con tus credenciales de Supabase:

```dart
   // Reemplaza con tus valores reales del proyecto
   const String SUPABASE\_URL = 'https://jgwcndehkoumpcddanyo.supabase.co';
   const String SUPABASE\_ANON\_KEY = 'tu\_anon\_key\_aqui';
   ```

4. **Ejecutar la aplicación:**

```bash
   flutter run
   ```

## Permisos Requeridos

Para que la aplicación funcione correctamente en dispositivos físicos, asegúrate de otorgar los siguientes permisos (ya configurados en `AndroidManifest.xml` e `Info.plist`):

* **Cámara:** Para escanear códigos y tomar fotos de productos.
* **Almacenamiento/Fotos:** Para seleccionar imágenes de la galería para los perfiles y productos.
* **Internet:** Para comunicarse con Supabase.

## Contribución

Si deseas contribuir a este proyecto, por favor crea un *fork* del repositorio, crea una nueva rama para tus cambios, y abre un *Pull Request* para revisión.

## Licencia

Este proyecto está bajo la Licencia MIT - mira el archivo [LICENSE.md](LICENSE.md) para más detalles.

