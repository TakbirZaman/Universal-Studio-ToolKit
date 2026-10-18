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
        self.bytes
            .try_reserve_exact(data.len())
            .map_err(io::Error::other)?;
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
    fn budget_failure_does_not_append_partial_data() {
        let mut buffer = BoundedBuffer::new(5);
        buffer.write_all(b"1234").unwrap();
        assert!(buffer.write_all(b"56").is_err());
        assert!(buffer.exceeded);
        assert_eq!(buffer.into_inner(), b"1234");
    }
}
