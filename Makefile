DOCKER ?= docker compose

local-frontend:
	$(DOCKER) up frontend

local-backend:
	$(DOCKER) up backend

local-env:
	$(DOCKER) up

