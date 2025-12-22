# Автоматизированный деплой проекта

## Шаги деплоя

- [x] 1. **Триггер workflow**  
      - Workflow запускается при push в ветку `main`

- [x] 2. **Checkout репозитория**  
      - Используется `actions/checkout@v4`

- [x] 3. **Подготовка тега Docker образа**  
      - Берём первые 6–8 символов Git commit hash  
      - Сохраняем в `IMAGE_TAG`

- [x] 4. **Login в GitHub Container Registry (GHCR)**  
      - Используем `docker/login-action@v3`  
      - Через `GITHUB_TOKEN` и `ghcr.io`

- [x] 5. **Сборка Docker образа**  
      - `docker build -t $IMAGE_NAME:$IMAGE_TAG .`  
      - Для текущего Python проекта  

- [x] 6. **Пуш Docker образа в GHCR**  
      - `docker push $IMAGE_NAME:$IMAGE_TAG`  
