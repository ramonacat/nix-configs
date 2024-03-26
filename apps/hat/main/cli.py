import asyncio
from zigpy_deconz.zigbee.application import ControllerApplication

async def async_main():
    app = ControllerApplication(ControllerApplication.SCHEMA(data = {
        "database_path": "/var/hat/zigbee.db",
        "device": {
            "path": "/dev/ttyACM0",
        }
    }))

    await app.startup(auto_form=True)

    # Permit joins for a minute
    await app.permit(60)
    await asyncio.sleep(60)

    # Just run forever
    await asyncio.get_running_loop().create_future()

def main():
    asyncio.run(async_main())
