# Generic Build Action

Acción de GitHub para compilar y testear aplicaciones .NET y TypeScript.

## Descripción

Esta acción permite compilar y ejecutar pruebas de aplicaciones en distintos lenguajes (actualmente .NET y TypeScript), subiendo los artefactos generados y reportes de cobertura como artefactos del workflow.

## Parámetros de entrada

- **language**: Lenguaje de la aplicación (`dotnet` o `typescript`). **Obligatorio**.
- **command**: Comando a ejecutar (`build` o `test`). **Obligatorio**.

### Parámetros para TypeScript

- **node-version**: Versión de Node.js a usar (por defecto: `14.x`, `16.x`, `18.x`, `20.x`).
- **typescript-framework**: Framework de la aplicación Node.js (por defecto: `angular`).

### Parámetros para .NET

- **dotnet-version**: Versión de .NET a usar (por defecto: `6.0.x`, `7.0.x`, `8.0.x`).
- **dotnet-selfcontained**: Si el empaquetado debe ser self-contained (`true` o `false`, por defecto: `false`).

## Salidas

- **package-name**: Nombre del paquete generado.
- **package-extension**: Extensión del paquete generado (ej: `zip`).
- **release-version**: Versión de la aplicación generada.
- **assets**: Artefactos generados por el empaquetado.

## Ejemplo de uso

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build .NET
        uses: ./build-action
        with:
          language: dotnet
          command: build
          dotnet-version: 8.0.x
          dotnet-selfcontained: false

      - name: Test TypeScript
        uses: ./build-action
        with:
          language: typescript
          command: test
          node-version: 20.x
          typescript-framework: angular
```

## Notas

- Puedes agregar soporte para otros lenguajes o frameworks extendiendo los parámetros y scripts correspondientes.
- Los artefactos generados se suben automáticamente como parte del workflow.
- Si necesitas personalizar la lógica de build/test, modifica los scripts `dotnet.ps1` o `node.ps1` según corresponda.

---
DevOps Mario Fribla Gonzalez

