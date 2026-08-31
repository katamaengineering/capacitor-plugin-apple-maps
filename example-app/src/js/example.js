import { CapacitorAppleMaps } from 'capacitor-plugin-apple-maps';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    CapacitorAppleMaps.echo({ value: inputValue })
}
