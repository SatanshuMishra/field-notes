package dev.satanshumishra.field_notes.uploads

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UploadItemAddressTest {
    @Test
    fun `an upload goes to an HTTPS server`() {
        assertTrue(UploadItem.isAllowedAddress("https://sync.satanshu.tech/v1/parts"))
        assertTrue(UploadItem.isAllowedAddress("https://10.0.0.5:8443/v1/parts"))
    }

    @Test
    fun `plain HTTP is refused beyond the device itself`() {
        assertFalse(UploadItem.isAllowedAddress("http://sync.satanshu.tech/v1/parts"))
        assertFalse(UploadItem.isAllowedAddress("http://10.0.0.5:8080/v1/parts"))
        assertFalse(UploadItem.isAllowedAddress("http://127.0.0.1.nip.io/v1/parts"))
        assertFalse(UploadItem.isAllowedAddress("ftp://sync.satanshu.tech/v1/parts"))
        assertFalse(UploadItem.isAllowedAddress("not a url"))
    }

    @Test
    fun `a server on the device itself may use plain HTTP`() {
        assertTrue(UploadItem.isAllowedAddress("http://127.0.0.1:8080/part"))
        assertTrue(UploadItem.isAllowedAddress("http://localhost:8080/part"))
        assertTrue(UploadItem.isAllowedAddress("http://[::1]:8080/part"))
    }
}
