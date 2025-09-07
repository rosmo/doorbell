import logging
import aiohttp
from typing import Any

from homeassistant.components.image import ImageEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType, UndefinedType
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from propcache.api import cached_property

from .const import DOMAIN, CONF_ID, CONF_NAME, CONF_TOKEN, CONF_HOST, CONF_PORT

_LOGGER = logging.getLogger(__name__)

async def async_setup_platform(hass: HomeAssistant, config: ConfigType, add_entities: AddEntitiesCallback, discovery_info: DiscoveryInfoType | None = None) -> None:
    if discovery_info is None:
        return

    conf = hass.data[DOMAIN]
    add_entities([DoorbellImage(hass, False, conf)])

class DoorbellImage(ImageEntity):
    def __init__(self, hass: HomeAssistant, verify_ssl: bool = False, conf: dict = {}):
        super().__init__(hass, verify_ssl)

        self._attr_image_url = f"http://{conf[CONF_HOST]}:{conf[CONF_PORT]}/cameraimage"
        self._name = conf[CONF_NAME]

        _LOGGER.info(f"Adding image entity with conf: {conf}")
        
    @property
    def name(self):
        return f"{self._name} Image"

    @cached_property
    def image_url(self) -> str | None | UndefinedType:
        """Return URL of image."""
        return self._attr_image_url