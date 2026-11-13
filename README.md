# Maze Adventure

Videojuego 2D de laberintos desarrollado con Flutter. Incluye cinco mundos
temáticos progresivos (Bosque Encantado, Mansión del Terror, Templo de la
Jungla, Laboratorio Futurista y Reino de Lava), cuatro personajes vectoriales,
tiradas de dado que limitan el movimiento, obstáculos, enemigos patrulleros,
llaves, linterna, vidas, estrellas, cronómetro, puntuación y guardado local del
progreso. Los controles funcionan con pantalla táctil, teclado o gestos. La
música y los efectos son WAV originales locales incluidos en `assets/audio/`.
En computadora, WASD o las flechas mueven al jugador; Espacio ataca, R lanza el
dado, E interactúa, Shift activa el escudo y Escape pausa. Las teclas 1–4
seleccionan poderes desbloqueados; los botones táctiles ofrecen las mismas
acciones. Cajas, telarañas, plantas, rocas, barreras y cristales tienen
resistencias y vulnerabilidades distintas.

## Ejecutar

```shell
flutter pub get
flutter devices
flutter run
flutter build apk --debug
```

En Windows, si Flutter informa que no puede crear enlaces simbólicos al
registrar los plugins, habilita el **Modo de desarrollador** de Windows y
vuelve a ejecutar `flutter pub get`.

Si Gradle solicita el NDK, instala la versión indicada por `flutter.ndkVersion`
desde **Android Studio > SDK Manager > SDK Tools > NDK (Side by side)**.

## Validar

```shell
flutter analyze
flutter test
```

El nombre del alumno se puede escribir en la pantalla principal antes de jugar.
La sección de configuración permite guardar las preferencias de música, efectos
y sus volúmenes.

`shared_preferences` conserva opciones y récords; `audioplayers` reproduce la
música en bucle y los efectos WAV locales.

El nivel siguiente se desbloquea al completar el anterior. En el juego, lanza
el dado y mueve con las flechas de pantalla, WASD, las flechas del teclado o un
deslizamiento sobre el laberinto. R lanza el dado; Espacio usa el poder equipado.
Escape pausa.

El menú principal adapta una o dos columnas al ancho disponible y mantiene el
crédito de autoría visible. La pantalla **Instrucciones de juego** describe
controles, poderes, enemigos, obstáculos, recompensas y mundos; los tests
responsivos recorren referencias desde 320 × 568 hasta 1920 × 1080.
