use std::io::{self, Write};

/// Refuse encoded bytes before growing beyond the operation budget.
pub(crate) struct BoundedBuffer {
    bytes: Vec<u8>,
    limit: usize,
    pub(crate) exceeded: bool,
}
impl BoundedBuffer {
    pub(crate) fn new(limit: usize) -> Self {
        Self {
            bytes: Vec::new(),
            limit,
            exceeded: false,
        }
    }
    pub(crate) fn into_inner(self) -> Vec<u8> {
        self.bytes
    }
}
impl Write for BoundedBuffer {
    fn write(&mut self, data: &[u8]) -> io::Result<usize> {
        if data.len() > self.limit.saturating_sub(self.bytes.len()) {
            self.exceeded = true;
            return Err(io::Error::other("Encoded output exceeds its byte budget."));
        }
        let required = self.bytes.len() + data.len();
        if required > self.bytes.capacity() {
            let target = required
                .max(self.bytes.capacity().saturating_mul(2))
                .max(4096)
                .min(self.limit);
            self.bytes
                .try_reserve_exact(target - self.bytes.len())
                .map_err(io::Error::other)?;
        }
        self.bytes.extend_from_slice(data);
        Ok(data.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn small_codec_writes_use_bounded_amortized_growth() {
        let mut buffer = BoundedBuffer::new(35000);
        let mut changes = 0;
        let mut previous = 0;
        for _ in 0..32000 {
            buffer.write_all(b"x").unwrap();
            let capacity = buffer.bytes.capacity();
            assert!(capacity <= 35000);
            if capacity != previous {
                changes += 1;
                previous = capacity;
            }
        }
        assert!(changes < 16);
        assert_eq!(buffer.into_inner().len(), 32000);
    }
    #[test]
    fn budget_failure_does_not_append_partial_data() {
        let mut buffer = BoundedBuffer::new(5);
        buffer.write_all(b"1234").unwrap();
        assert!(buffer.write_all(b"56").is_err());
        assert!(buffer.exceeded);
        assert_eq!(buffer.into_inner(), b"1234");
    }
}
