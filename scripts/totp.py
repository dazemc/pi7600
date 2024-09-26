"""This is an example demonstrating sqlalchemy with timebased one time passwords(TOTP)"""

from sqlalchemy import create_engine, Column, Integer, String, Boolean
from sqlalchemy.orm import sessionmaker, Session, declarative_base
import pyotp
import qrcode
from io import BytesIO
from PIL import Image


# 1. Define the DatabaseManager class
class DatabaseManager:
    """
    Manages the database connection, session, and provides methods to interact with the database.
    """

    def __init__(self, db_url: str):
        # Initialize the database engine
        self.engine = create_engine(db_url, connect_args={"check_same_thread": False})

        # Create a session factory
        self.SessionLocal = sessionmaker(
            autocommit=False, autoflush=False, bind=self.engine
        )

        # Base class for declarative models
        self.Base = declarative_base()

        # Initialize the User model (defined later)
        self.User = None

    def create_tables(self):
        """
        Creates tables in the database based on the defined models.
        """
        self.Base.metadata.create_all(bind=self.engine)

    def get_session(self) -> Session:
        """
        Creates and returns a new database session.
        """
        return self.SessionLocal()


# 2. Define the User model class
class UserModel:
    """
    Defines the User model with SQLAlchemy ORM.
    """

    def __init__(self, Base):
        # Define the User class within the scope of this method to tie it to the provided Base
        class User(Base):
            __tablename__ = "users"
            id = Column(Integer, primary_key=True, index=True)
            username = Column(String, unique=True, index=True)
            email = Column(String, unique=True, index=True)
            totp_secret = Column(String, nullable=False)
            is_active = Column(Boolean, default=True)

        self.User = User


# 3. Define the TOTPManager class
class TOTPManager:
    """
    Manages TOTP generation, QR code creation, and verification.
    """

    def generate_totp_secret(self) -> str:
        """
        Generates a new base32-encoded secret for TOTP.
        """
        return pyotp.random_base32()

    def generate_qr_code(self, username: str, totp_secret: str) -> Image.Image:
        """
        Generates a QR code image for Google Authenticator setup.
        """
        # Create the provisioning URI
        totp_uri = pyotp.totp.TOTP(totp_secret).provisioning_uri(
            name=username, issuer_name="SecureApp"
        )

        # Generate the QR code
        qr = qrcode.make(totp_uri)

        # Save the QR code to a BytesIO stream
        qr_code_stream = BytesIO()
        qr.save(qr_code_stream, format="PNG")
        qr_code_stream.seek(0)

        # Convert to an image and return
        qr_image = Image.open(qr_code_stream)
        return qr_image

    def verify_totp_code(self, totp_secret: str, code: str) -> bool:
        """
        Verifies a TOTP code provided by the user.
        """
        totp = pyotp.TOTP(totp_secret)
        return totp.verify(code)


# 4. Define the UserService class
class UserService:
    """
    Provides methods to interact with user data in the database.
    """

    def __init__(self, db_manager: DatabaseManager, totp_manager: TOTPManager):
        self.db_manager = db_manager
        self.totp_manager = totp_manager
        self.User = db_manager.User

    def create_user(self, username: str, email: str) -> None:
        """
        Creates a new user with a TOTP secret and adds them to the database.
        """
        session = self.db_manager.get_session()
        try:
            # Check if the user already exists
            existing_user = (
                session.query(self.User).filter(self.User.username == username).first()
            )
            if existing_user:
                print(f"User '{username}' already exists.")
                return

            # Generate a TOTP secret
            totp_secret = self.totp_manager.generate_totp_secret()

            # Create a new user instance
            new_user = self.User(
                username=username, email=email, totp_secret=totp_secret, is_active=True
            )

            # Add and commit the new user to the database
            session.add(new_user)
            session.commit()
            session.refresh(new_user)

            # Generate and display the QR code
            qr_image = self.totp_manager.generate_qr_code(username, totp_secret)
            qr_image.show()  # Opens the QR code image using the default image viewer
            print(
                f"User '{username}' created successfully. Scan the QR code with Google Authenticator."
            )
        finally:
            session.close()

    def verify_user_totp(self, username: str, code: str) -> bool:
        """
        Verifies the TOTP code for a given user.
        """
        session = self.db_manager.get_session()
        try:
            # Retrieve the user from the database
            user = (
                session.query(self.User).filter(self.User.username == username).first()
            )
            if not user:
                print(f"User '{username}' not found.")
                return False

            # Verify the TOTP code
            if self.totp_manager.verify_totp_code(user.totp_secret, code):
                print("TOTP code is valid!")
                return True
            else:
                print("Invalid TOTP code.")
                return False
        finally:
            session.close()


# 5. Main execution flow
if __name__ == "__main__":
    # Database URL for SQLite
    DATABASE_URL = "sqlite:///./users_oop.db"

    # Initialize the DatabaseManager
    db_manager = DatabaseManager(DATABASE_URL)

    # Initialize the User model and tie it to the Base
    user_model = UserModel(db_manager.Base)
    db_manager.User = user_model.User  # Assign the User class to the DatabaseManager

    # Create the tables in the database
    db_manager.create_tables()

    # Initialize the TOTPManager
    totp_manager = TOTPManager()

    # Initialize the UserService
    user_service = UserService(db_manager, totp_manager)

    # Create a new user and generate a QR code for TOTP setup
    username = "alice"
    email = "alice@example.com"
    user_service.create_user(username, email)

    # Prompt the user to enter the TOTP code from Google Authenticator
    user_code = input("Enter the TOTP code from Google Authenticator: ")

    # Verify the TOTP code
    user_service.verify_user_totp(username, user_code)
